h5p_set_virtual(dcpl_id, vspace_id, src_file_name, src_dset_name, src_space_id) = 
    ccall((:H5Pset_virtual, libhdf5), Herr, (Hid, Hid, Ptr{UInt8}, Ptr{UInt8}, Hid), dcpl_id, vspace_id, src_file_name, src_dset_name, src_space_id)

mutable struct VirtualLayout{S, D, SS}
    shape::S
    dtype::D
    sources::SS
end

VirtualLayout(shape, dtype) = VirtualLayout(tuple(shape...), dtype, [])

repcolon(is, shape) = ifelse.(is .== Colon(), Base.OneTo.(shape), is)

function Base.setindex!(layout::VirtualLayout, v, is...)
    push!(layout.sources, (repcolon(is, layout.shape), v))
    shape = collect(layout.shape)
    for (vis, vs) in layout.sources
        layout.shape = max.(layout.shape, last.(vis))
    end
end

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
    VirtualSource(filename(dset), name(dset), size(dset), eltype(dset), nothing)

Base.getindex(vs::VirtualSource, is...) = VirtualSource(vs.path, vs.name, vs.shape, vs.dtype, repcolon(is, vs.shape))

function select_hyperslab(dspace, is)
    isnothing(is) && return dspace
    start = [i[1] - 1 for i in reverse(is)]
    count = [1 for i in is]
    stride = [step(i) for i in is]
    block = [length(i) for i in reverse(is)]
    h5s_select_hyperslab(dspace, H5S_SELECT_SET, start, stride, count, block)
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
