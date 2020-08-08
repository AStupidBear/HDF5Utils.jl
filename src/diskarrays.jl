mutable struct HDF5DiskArray{T, N, C, D, R} <: AbstractDiskArray{T, N}
    ds::HDF5Dataset
    cs::C
    lo::NTuple{N, Int}
    hi::NTuple{N, Int}
    cache::Array{T, D}
end

Base.size(x::HDF5DiskArray{T, N}) where {T, N} = size(x.ds)::NTuple{N, Int}

haschunks(x::HDF5DiskArray{<:Any, <:Any, Nothing}) = Chunked()
haschunks(x::HDF5DiskArray) = Unchunked()

eachchunk(x::HDF5DiskArray{<:Any, <:Any, <:GridChunks}) = x.cs

readblock!(x::HDF5DiskArray, aout, r::AbstractUnitRange...) = aout .= x.ds[r...]

writeblock!(x::HDF5DiskArray, v, r::AbstractUnitRange...) = x.ds[r...] = v

const _cache_size = Ref(10 * 1024^2)

function set_cache_size(cache_size)
    _cache_size[] = cache_size
end

get_cache_size() = _cache_size[]

get_cache_size(ds::HDF5Dataset) = _cache_size[] ÷ sizeof(eltype(ds))

function HDF5DiskArray(ds::HDF5Dataset)
    cs = try
        disable_dag()
        GridChunks(ds, get_chunk(ds))
        enable_dag()
    catch
        nothing
    end
    T, N, C = eltype(ds), ndims(ds), typeof(cs)
    strides = cumprod(collect(size(ds)))
    D = findlast(strides .< get_cache_size(ds))
    D = min(something(D, 1) + 1, N)
    if D == 1
        R = min(get_cache_size(ds), size(ds, 1))
    else
        R = min(ceil(Int, get_cache_size(ds) / strides[D - 1]), size(ds, D))
    end
    lo, hi = ntuple(zero, N), ntuple(zero, N)
    cache = zeros(T, size(ds)[1:(D - 1)]..., 0)
    HDF5DiskArray{T, N, C, D, R}(ds, cs, lo, hi, cache)
end

@generated function _getindex(x::HDF5DiskArray{T, N, C, D, R}, r::Integer...) where {T, N, C, D, R}
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

Base.Array(x::HDF5DiskArray) = read(x.ds)

Base.getindex(x::HDF5DiskArray{T, N}, is::Vararg{Union{AbstractVector, Colon}, N}) where {T, N} = getindex(x.ds, is...)