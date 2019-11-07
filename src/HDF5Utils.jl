module HDF5Utils

using Random, Distributed, Requires, Glob
using HDF5, FillArrays, ProgressMeter
using FillArrays: Zeros, Fill

using HDF5: HDF5Dataset, DatasetOrAttribute, HDF5Compound
using HDF5: H5T_COMPOUND, H5T_STRING, H5P_DEFAULT, H5S_ALL, H5P_FILE_ACCESS, Herr, Hid, Hsize
using HDF5: h5t_create, h5t_insert, h5t_close, h5t_copy, h5t_get_size, h5t_set_size
using HDF5: h5t_get_class, h5t_get_nmembers, h5t_get_member_type, h5t_get_member_name
using HDF5: hdf5_type_id, hdf5_to_julia, hdf5_to_julia_eltype, writearray, readarray
using HDF5: h5t_is_variable_str, h5d_write, isnull, libhdf5

using HDF5: HDF5Dataset, DatasetOrAttribute, HDF5Compound
using HDF5: H5T_COMPOUND, H5T_STRING, H5P_DEFAULT, H5S_ALL, H5P_FILE_ACCESS, H5S_SCALAR, H5T_CSET_UTF8
using HDF5: h5t_create, h5t_insert, h5t_close, h5t_copy, h5t_get_size, h5t_set_size, h5t_set_cset
using HDF5: h5t_get_class, h5t_get_nmembers, h5t_get_member_type, h5t_get_member_name
using HDF5: hdf5_type_id, hdf5_to_julia, hdf5_to_julia_eltype
using HDF5: h5t_is_variable_str, h5s_create, h5d_write
using HDF5: Herr, Hid, Hsize, isnull, libhdf5, writearray, readarray

export d_zeros, copy_batch!, write_batch
export read_nonarray, write_nonarray
export h5load, h5save, h5readmmap, tryreadmmap
export h5concat, h5concat_bigdata
export MaxLenString, MLString

include("util.jl")
include("batch.jl")
include("concat.jl")
include("io.jl")
include("alignment.jl")
include("conversion.jl")
include("mlstring.jl")
include("namedtuple.jl")

end # module
