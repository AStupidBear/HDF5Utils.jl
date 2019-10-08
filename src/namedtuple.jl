function HDF5.hdf5_type_id(::Type{T}) where T <: NamedTuple
    type_id = h5t_create(H5T_COMPOUND, sizeof(T))
    for i in 1:fieldcount(T)
        fname = string(fieldname(T, i))
        offset = fieldoffset(T, i)
        ftype = fieldtype(T, i)
        fid = hdf5_type_id(ftype)
        h5t_insert(type_id, fname, offset, fid)
        ftype <: MaxLenString && h5t_close(fid)
    end
    type_id
end

@h5bitslike NamedTuple