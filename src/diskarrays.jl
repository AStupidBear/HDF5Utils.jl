mutable struct HDF5DiskArray{T, N, C, D} <: AbstractDiskArray{T, N}
    ds::HDF5Dataset
    cs::C
    is::NTuple{N, Int}
    cache::Array{T, D}
end

Base.size(x::HDF5DiskArray) = size(x.ds)

haschunks(x::HDF5DiskArray{<:Any, <:Any, Nothing}) = Chunked()
haschunks(x::HDF5DiskArray) = Unchunked()

eachchunk(x::HDF5DiskArray{<:Any, <:Any, <:GridChunks}) = x.cs

readblock!(x::HDF5DiskArray, aout, r::AbstractUnitRange...) = aout .= x.ds[r...]

writeblock!(x::HDF5DiskArray, v, r::AbstractUnitRange...) = x.ds[r...] = v

function HDF5DiskArray(ds::HDF5Dataset)
    cs = try
        GridChunks(ds, get_chunk(ds))
    catch
        nothing
    end
    T, N, C = eltype(ds), ndims(ds), typeof(cs)
    D = findlast(cumprod(collect(size(ds))) .< 1024)
    is = ntuple(z -> 1, ndims(ds))
    cache = ds[fill(:, D)..., fill(1, N - D)...]
    cache = reshape(cache, size(ds)[1:D])
    HDF5DiskArray{T, N, C, D}(ds, cs, is, cache)
end

@generated function Base.getindex(x::HDF5DiskArray{T, N, C, D}, r::Integer...) where {T, N, C, D}
    colons = fill(:(:), D)
    rl = [:(r[$d]) for d in 1:D]
    rr = [:(r[$d]) for d in D+1:N]
    cond = :()
    for d in (D + 1):N
        cond = isempty(cond.args) ? :(r[$d] != x.is[$d]) : :($cond || r[$d] != x.is[$d])
    end
    ex = quote
        @inbounds if $cond
            x.is = r
            x.cache = x[$(colons...), $(rr...)]
        end
        1
        @inbounds v = x.cache[$(rl...)]
        return v
    end
    return ex
end