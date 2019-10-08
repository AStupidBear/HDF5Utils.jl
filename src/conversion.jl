function HDF5.hdf5_to_julia_eltype(objtype::HDF5Datatype)
    class_id = h5t_get_class(objtype.id)
    if class_id == H5T_STRING
        isvar = h5t_is_variable_str(objtype.id)
        n = Int(h5t_get_size(objtype.id))
        !isvar && 1 < n < 32 && return MaxLenString{n}
    elseif class_id == H5T_COMPOUND
        n = Int(h5t_get_nmembers(objtype.id))
        field_names = Symbol[]
        field_types = DataType[]
        for i in 0:(n - 1)
            field_tid = h5t_get_member_type(objtype.id, i)
            field_type = hdf5_to_julia_eltype(HDF5Datatype(field_tid))
            field_name = h5t_get_member_name(objtype.id, i)
            push!(field_names, Symbol(field_name))
            push!(field_types, field_type)
        end
        T = NamedTuple{tuple(field_names...), Tuple{field_types...}}
        return T
    end
    invoke(hdf5_to_julia_eltype, Tuple{Any}, objtype)
end

macro h5bitslike(T)
    quote
        HDF5.datatype(::T) where T <: $T = HDF5Datatype(hdf5_type_id(T))

        HDF5.datatype(A::AbstractArray{T}) where T <: $T = HDF5Datatype(hdf5_type_id(T))

        HDF5.read(obj::DatasetOrAttribute, ::Type{T}) where T <: $T = read(obj, Array{T})[1]
        
        function HDF5.read(obj::HDF5Dataset, ::Type{Array{T}}) where T <: $T
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

        function HDF5.write(obj::DatasetOrAttribute, x::Union{T, Array{T}}) where T <: $T
            dtype = datatype(x)
            try
                writearray(obj, dtype.id, x)
            finally
            close(dtype)
            end
        end

        HDF5.write(parent::Union{HDF5File, HDF5Group}, name::String, data::Union{T, AbstractArray{T}}, plists...) where  T <: $T =
            d_write(parent, name, data, plists...)

        HDF5.d_write(parent::Union{HDF5File, HDF5Group}, name::String, data::Union{T, AbstractArray{T}}, plists...) where T <: $T =
            HDF5._d_write(parent, name, data, plists...)

        HDF5.d_create(parent::Union{HDF5File, HDF5Group}, name::String, data::Union{T, AbstractArray{T}}, plists...) where T <: $T =
            HDF5._d_create(parent, name, data, plists...)

        HDF5.dataspace(::T) where T <: $T = HDF5Dataspace(HDF5.h5s_create(H5S_SCALAR))

        function HDF5.h5d_write(dataset_id::Hid, memtype_id::Hid, x::T, xfer::Hid = H5P_DEFAULT) where T <: $T
            h5d_write(dataset_id, memtype_id, H5S_ALL, H5S_ALL, xfer, Ref{T}(x))
        end

        HDF5.ismmappable(::Type{Array{T}}) where T <: $T = true
    end |> esc
end