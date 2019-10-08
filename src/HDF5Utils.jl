module HDF5Utils

using HDF5, FillArrays, ProgressMeter, Glob, Requires
using FillArrays: Zeros, Fill

using HDF5: HDF5Dataset, DatasetOrAttribute, HDF5Compound
using HDF5: Herr, Hid, Hsize, libhdf5, H5P_FILE_ACCESS, p_create
using HDF5: h5t_copy, hdf5_type_id, h5t_get_size, h5t_set_size, h5t_set_cset
using HDF5: cset, hdf5_to_julia, h5d_write, Hid, H5P_DEFAULT, H5S_ALL
using HDF5: H5T_COMPOUND, h5t_get_class, h5t_get_nmembers, h5t_get_member_type
using HDF5: hdf5_to_julia_eltype, h5t_get_member_name, writearray

export d_zeros, h5load, h5save, h5readmmap, tryreadmmap, h5concat, h5concat_bigdata

include("util.jl")
include("batch.jl")
include("concat.jl")
include("string.jl")
include("io.jl")
include("namedtuple.jl")
include("alignment.jl")

end # module
