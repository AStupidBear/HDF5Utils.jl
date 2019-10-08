function HDF5.datatype(str::Array{S}) where {S <: String}
    type_id = h5t_copy(hdf5_type_id(S))
    h5t_set_size(type_id, maximum(sizeof, str) + 1)
    h5t_set_cset(type_id, cset(S))
    HDF5Datatype(type_id)
end

function HDF5.h5d_write(dataset_id::Hid, memtype_id::Hid, strs::Array{S}, xfer::Hid = H5P_DEFAULT) where {S <: String}
    x = zeros(UInt8, h5t_get_size(memtype_id), length(strs))
    for i in 1:length(strs)
        copyto!(view(x, :, i), unsafe_wrap(Vector{UInt8}, strs[i]))
    end
    h5d_write(dataset_id, memtype_id, H5S_ALL, H5S_ALL, xfer, x)
end

HDF5.write(parent::Union{HDF5File, HDF5Group}, name::String, data::AbstractArray{T}, plists...) where T <: AbstractString =
    d_write(parent, name, String.(data), plists...)

function HDF5.write(parent::Union{HDF5File, HDF5Group}, name::String, data::Dict, plists...)
    g = g_create(parent, name)
    for (k, v) in data
        write(g, k, v, plists...)
    end
end