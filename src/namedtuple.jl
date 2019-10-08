function HDF5.datatype(str::Array{S}) where {S <: NamedTuple}
    type_id = h5t_copy(hdf5_type_id(S))
    h5t_set_size(type_id, maximum(sizeof, str) + 1)
    h5t_set_cset(type_id, cset(S))
    HDF5Datatype(type_id)
end

function HDF5.read(obj::HDF5Dataset, ::Union{Type{Array{HDF5Compound{N}}},Type{HDF5Compound{N}}}) where {N}
    T = namedtuple_type(obj::HDF5Dataset)
    if isnull(obj)
        return T[]
    end
    dims = size(obj)
    data = Array{T}(undef, dims)
    dtype = datatype(data)
    readarray(obj, dtype.id, data)
    close(dtype)
    data
end

function namedtuple_type(obj::HDF5Dataset)
    """ Builds a NamedTuple type for a compound dataset """
    dtype = datatype(obj)
    class_id = h5t_get_class(dtype.id)
    n = Int(h5t_get_nmembers(dtype.id))
    field_names = Symbol[]
    field_types = DataType[]
    for i in 0:(n - 1)
        field_tid = h5t_get_member_type(dtype.id, i)
        field_type = hdf5_to_julia_eltype(HDF5Datatype(field_tid))
        field_name = h5t_get_member_name(dtype.id, i)
        push!(field_names, Symbol(field_name))
        push!(field_types, field_type)
    end
    T = NamedTuple{tuple(field_names...), Tuple{field_types...}}
end

function HDF5.write(obj::DatasetOrAttribute, x::Union{T, Array{T}}) where T <: NamedTuple
    dtype = datatype(x)
    try
        writearray(obj, dtype.id, x)
    finally
       close(dtype)
    end
end

HDF5.write(parent::Union{HDF5File, HDF5Group}, name::String, data::Union{T, AbstractArray{T}}, plists...) where  T <: NamedTuple =
    d_write(parent, name, data, plists...)