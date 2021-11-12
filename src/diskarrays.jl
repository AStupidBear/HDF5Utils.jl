mutable struct HDF5DiskArray{T, N, D, R} <: AbstractDiskArray{T, N}
    dset::HDF5Dataset
    chunks::GridChunks
    lo::NTuple{N, Int}
    hi::NTuple{N, Int}
    cache::Array{T, D}
    blkrange
    blkcache::Array{T, N}
end

Base.size(x::HDF5DiskArray{T, N}) where {T, N} = size(x.dset)::NTuple{N, Int}

haschunks(x::HDF5DiskArray) = Chunked()
eachchunk(x::HDF5DiskArray) = x.chunks

function readblock!(x::HDF5DiskArray, aout, r::OrdinalRange...)
    if x.blkrange != r
        x.blkrange = r
        x.blkcache = x.dset[r...]
    end
    aout .= x.blkcache
    return nothing
end

function readblock!(A::HDF5DiskArray, A_ret, r::AbstractVector...)
    r′ = map(i -> i isa OrdinalRange ? i : minimum(i):maximum(i), r)
    r′′ = map(i -> i isa OrdinalRange ? (:) : i .- i[1] .+ 1, r)
    if A.blkrange != r
        A_temp = similar(A_ret, length.(r′))
        readblock!(A, A_temp, r′...)
        A.blkrange = r
        A.blkcache = A_temp
    else
        A_temp = A.blkcache
    end
    A_ret .= view(A_temp, r′′...)
    nothing
end

writeblock!(x::HDF5DiskArray, v, r::OrdinalRange...) = x.dset[r...] = v

function writeblock!(A::HDF5DiskArray, A_ret, r::AbstractVector...)
    r′ = map(i -> i isa OrdinalRange ? i : minimum(i):maximum(i), r)
    r′′ = map(i -> i isa OrdinalRange ? (:) : i .- i[1] .+ 1, r)
    A_temp = similar(A_ret, length.(r′))
    A_temp[r′′...] = A_ret
    writeblock!(A, A_temp, r′...)
    nothing
end

const _cache_size = Ref(10 * 1024^2)

function set_cache_size(cache_size)
    _cache_size[] = cache_size
end

get_cache_size() = _cache_size[]

get_cache_size(dset::HDF5Dataset) = _cache_size[] ÷ sizeof(eltype(dset))

function HDF5DiskArray(dset::HDF5Dataset)
    if get(ENV, "HDF5_NOCHUNK", "0") == "1"
        chunks = GridChunks(dset, size(dset))
    else
        disable_dag()
        chunksize = try get_chunk(dset) catch e size(dset) end
        enable_dag()
        chunks = GridChunks(dset, chunksize)
    end
    T, N = eltype(dset), ndims(dset)
    strides = cumprod(collect(size(dset)))
    D = findlast(strides .< get_cache_size(dset))
    D = min(something(D, 1) + 1, N)
    if D == 1
        R = min(get_cache_size(dset), size(dset, 1))
    else
        R = min(ceil(Int, get_cache_size(dset) / strides[D - 1]), size(dset, D))
    end
    lo, hi = ntuple(zero, N), ntuple(zero, N)
    cache = zeros(T, size(dset)[1:(D - 1)]..., 0)
    blkrange = ntuple(d -> 1:0, N)
    blkcache = zeros(T, size(dset))
    HDF5DiskArray{T, N, D, R}(dset, chunks, lo, hi, cache, blkrange, blkcache)
end

@generated function _getindex(x::HDF5DiskArray{T, N, D, R}, r::Integer...) where {T, N, D, R}
    colons = fill(:(:), D - 1)
    rl = [:(r[$d]) for d in 1:(D - 1)]
    rr = [:(r[$d]) for d in (D + 1):N]
    cond = :(r[$D] < x.lo[$D] || r[$D] > x.hi[$D])
    for d in (D + 1):N
        cond = :($cond || r[$d] != x.lo[$d])
    end
    ex = quote
        @inbounds if $cond
            x.lo, x.hi = r, min.(r .+ $R, size(x))
            x.cache = x[$(colons...), x.lo[$D]:x.hi[$D], $(rr...)]
        end
        @inbounds v = x.cache[$(rl...), r[$D] - x.lo[$D] + 1]
        return v
    end
    return ex
end

Base.getindex(x::HDF5DiskArray, r::CartesianIndex) = _getindex(x, Tuple(r)...)

Base.getindex(x::HDF5DiskArray, r::Integer...) = _getindex(x, r...)

Base.getindex(x::HDF5DiskArray, i::Integer) =  getindex(x, CartesianIndices(x)[i])

Base.getindex(x::HDF5DiskArray{T, 1}, i::Integer) where T = _getindex(x, i)

Base._reshape(x::HDF5DiskArray, dims::NTuple{N, Int}) where N = Base.__reshape((x, IndexStyle(x)), dims)

Base.Array(x::HDF5DiskArray) = read(x.dset)
