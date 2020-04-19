function HDF5.h5open(filename::AbstractString, mode::AbstractString="r", pv...; swmr=false, fclose_degree = H5F_CLOSE_STRONG, auto_fclose = true)
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
    if auto_fclose
        try
            disable_dag()
            fid = h5open(filename, modes..., fcpl, fapl; swmr=swmr)
            enable_dag()
            fid
        catch e
            fapl["fclose_degree"] = H5F_CLOSE_DEFAULT
            h5open(filename, modes..., fcpl, fapl; swmr=swmr)
        end
    else
        h5open(filename, modes..., fcpl, fapl; swmr=swmr)
    end
end

function HDF5.h5open(f::Function, args...; ka...)
    fid = h5open(args...; ka...)
    try
        f(fid)
    finally
        close(fid)
    end
end

function HDF5.close(obj::HDF5File)
    if obj.id != -1
        flush(obj)
        h5f_close(obj.id)
        obj.id = -1
    end
    nothing
end

function h5load(src, ::Type{T}, pv...; mode = "r", mmaparrays = true, ka...) where T
    @eval GC.gc(true)
    fid = h5open(src, mode, pv...; ka...)
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

function h5load(src, paths = nothing, pv...; mode = "r", mmaparrays = true, ka...)
    @eval GC.gc(true)
    fid = h5open(src, mode, pv...; ka...)
    if isnothing(paths)
        obj = !Sys.iswindows() && mmaparrays ? tryreadmmap(fid) : read(fid)
    elseif paths isa AbstractArray
        obj = map(path -> tryreadmmap(fid[path]), paths)
    end
    finalizer(x -> HDF5.h5_garbage_collect(), obj)
    return obj
end

h5load(src, path::AbstractString, pv...; ka...) = h5load(src, [path], pv...; ka...)[1]

function h5save(dst, obj::T, pv...; excludes = [], ka...) where T
    @eval GC.gc(true)
    h5open(dst, "w", pv...; ka...) do fid
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
    end
    return dst
end

h5save(dst, dict::Dict, pv...; ka...) = h5open(fid -> write(fid, dict), dst, "w", pv...; ka...)

h5loadv(a...; ka...) = h5load(a...; fclose_degree = H5F_CLOSE_DEFAULT, ka...)