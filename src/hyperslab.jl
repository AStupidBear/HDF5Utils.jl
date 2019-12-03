function HDF5._getindex(dset::HDF5Dataset, T::Type, indices::Union{AbstractRange{Int},Int}...)
    dsel_id = hyperslab(dset, indices...)
    ret = Array{T}(undef,map(length, indices))
    memtype = datatype(ret)
    memspace = dataspace(ret)
    try
        h5d_read(dset.id, memtype.id, memspace.id, dsel_id, dset.xfer, ret)
    finally
        close(memtype)
        close(memspace)
        h5s_close(dsel_id)
    end
    ret
end

function HDF5._setindex!(dset::HDF5Dataset,T::Type, X::Array, indices::Union{AbstractRange{Int},Int}...)
    if !(T <: Array)
        error("Dataset indexing (hyperslab) is available only for arrays")
    end
    ET = eltype(T)
    if length(X) != prod(map(length, indices))
        error("number of elements in range and length of array must be equal")
    end
    if eltype(X) != ET
        X = convert(Array{ET}, X)
    end
    dsel_id = hyperslab(dset, indices...)
    memtype = datatype(X)
    memspace = dataspace(X)
    try
        h5d_write(dset.id, memtype.id, memspace.id, dsel_id, dset.xfer, X)
    finally
        close(memtype)
        close(memspace)
        h5s_close(dsel_id)
    end
    X
end