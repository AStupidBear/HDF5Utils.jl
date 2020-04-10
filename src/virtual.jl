function HDF5.h5open(filename::AbstractString, mode::AbstractString="r", pv...; fclose_degree=H5F_CLOSE_STRONG, swmr=false)
    checkprops(pv...)
    # pv is interpreted as pairs of arguments
    # the first of a pair is a key of hdf5_prop_get_set
    # the second of a pair is a property value
    fapl = p_create(H5P_FILE_ACCESS, true, pv...) # file access property list
    # With garbage collection, the other modes don't make sense
    # (Set this first, so that the user-passed properties can overwrite this.)
    fapl["fclose_degree"] = fclose_degree
    fcpl = p_create(H5P_FILE_CREATE, true, pv...) # file create property list
    modes =
        mode == "r"  ? (true,  false, false, false, false) :
        mode == "r+" ? (true,  true,  false, false, true ) :
        mode == "cw" ? (false, true,  true,  false, true ) :
        mode == "w"  ? (false, true,  true,  true,  false) :
        # mode == "w+" ? (true,  true,  true,  true,  false) :
        # mode == "a"  ? (true,  true,  true,  true,  true ) :
        error("invalid open mode: ", mode)
    h5open(filename, modes..., fcpl, fapl; swmr=swmr)
end

function HDF5.h5open(f::Function, args...; swmr=false, ka...)
    fid = h5open(args...; swmr=swmr, ka...)
    try
        f(fid)
    finally
        close(fid)
    end
end

h5p_set_virtual(dcpl_id, vspace_id, src_file_name, src_dset_name, src_space_id) = 
    ccall((:H5Pset_virtual, libhdf5), Herr, (Hid, Hid, Ptr{UInt8}, Ptr{UInt8}, Hid), dcpl_id, vspace_id, src_file_name, src_dset_name, src_space_id)

struct VirtualLayout{S, D, SS}
    shape::S
    dtype::D
    sources::SS
end

VirtualLayout(shape, dtype) = VirtualLayout(shape, dtype, [])

repcolon(is, shape) = ifelse.(is .== Colon(), Base.OneTo.(shape), is)

Base.setindex!(layout::VirtualLayout, v, is...) = push!(layout.sources, (repcolon(is, layout.shape), v))

struct VirtualSource{P, N, S, D, I}
    path::P
    name::N
    shape::S
    dtype::D
    is::I
end

function VirtualSource(path, name)
    dset = h5open(path, "r")[name]
    shape, dtype = size(dset), eltype(dset)
    VirtualSource(path, name, shape, dtype, nothing)
end

VirtualSource(dset::HDF5Dataset) = 
    VirtualSource(file(dset), name(dset), size(dset), eltype(dset), nothing)

Base.getindex(vs::VirtualSource, is...) = VirtualSource(vs.path, vs.name, vs.shape, vs.dtype, repcolon(is, vs.shape))

function select_hyperslab(dspace, is)
    isnothing(is) && return dspace
    start = [i[1] - 1 for i in reverse(is)]
    count = [1 for i in is]
    stride = [step(i) for i in is]
    block = [length(i) for i in reverse(is)]
    h5s_select_hyperslab(dspace, H5S_SELECT_SET, start, count, count, block)
    return dspace
end

function d_create_virtual(parent::Union{HDF5File, HDF5Group}, name::String, layout)
    checkvalid(parent)
    dcpl = p_create(H5P_DATASET_CREATE)
    dspace = dataspace(layout.shape)
    dtype = datatype(layout.dtype)
    for (is, vs) in layout.sources
        src_dspace = dataspace(vs.shape)
        select_hyperslab(dspace, is)
        select_hyperslab(src_dspace, vs.is)
        h5p_set_virtual(dcpl, dspace, vs.path, vs.name, src_dspace)
    end
    d_create(parent, name, dtype, dspace, HDF5Properties(), dcpl)
end
