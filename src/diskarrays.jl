using DiskArrays

import DiskArrays: eachchunk, haschunks, readblock!, writeblock!, GridChunks, Chunked, Unchunked

export HDF5DiskArray

struct HDF5DiskArray{T, N, CS} <: AbstractDiskArray{T, N}
  ds::HDF5Dataset
  cs::CS
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
    HDF5DiskArray{eltype(ds), ndims(ds), typeof(cs)}(ds, cs)
end