function h5open_weak(filename::AbstractString, mode::AbstractString="r", pv...; swmr=false)
    checkprops(pv...)
    # pv is interpreted as pairs of arguments
    # the first of a pair is a key of hdf5_prop_get_set
    # the second of a pair is a property value
    fapl = p_create(H5P_FILE_ACCESS, true, pv...) # file access property list
    # With garbage collection, the other modes don't make sense
    # (Set this first, so that the user-passed properties can overwrite this.)
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

function h5load(src, ::Type{T}; mode = "r", mmaparrays = true, virtual = false) where T
    @eval GC.gc(true)
    fid = (virtual ? h5open_weak : h5open)(src, mode)
    o, r = Any[], !Sys.iswindows() && mmaparrays ? tryreadmmap : read
    for s in fieldnames(T)
        ft = fieldtype(T, s)
        if ft <: AbstractArray
            x = string(s) ∈ names(fid) ? r(fid[string(s)]) :
                zeros(ft.parameters[1], ntuple(i -> 0, ft.parameters[2]))
            else
                x = ft(read_nonarray(fid, string(s)))
            end
            push!(o, x)
        end
        obj = T(o...)
        finalizer(x -> HDF5.h5_garbage_collect(), obj)
        return obj
    end
    
function h5load(src; mode = "r", mmaparrays = true, virtual = false)
    @eval GC.gc(true)
    fid = (virtual ? h5open_weak : h5open)(src, mode)
    obj = !Sys.iswindows() && mmaparrays ? tryreadmmap(fid) : read(fid)
    finalizer(x -> HDF5.h5_garbage_collect(), obj)
    return obj
end

function h5save(dst, obj::T; excludes = []) where T
    isfile(dst) && rm(dst)
    isempty(dst) && error("dst is empty")
    h5open(dst, "w", "alignment", (0, 8)) do fid
        for s in fieldnames(typeof(obj))
            s ∈ excludes && continue
            x = getfield(obj, s)
            if isa(x, AbstractArray)
                write_batch(fid, string(s), x)
            elseif isa(x, HDF5Dataset)
                HDF5.create_external(fid, s, filename(x), name(x))
            else
                write_nonarray(fid, string(s), x)
            end
        end
        flush(fid)
    end
    return dst
end

h5save(dst, dict::Dict) = h5open(f -> write(f, dict), dst, "w", "alignment", (0, 8))