function HDF5.h5open(filename::AbstractString, mode::AbstractString="r", pv...; swmr=false, fclose_degree = H5F_CLOSE_STRONG, auto_fclose = true)
    checkprops(pv...)
    # pv is interpreted as pairs of arguments
    # the first of a pair is a key of hdf5_prop_get_set
    # the second of a pair is a property value
    fapl = p_create(H5P_FILE_ACCESS, pv...) # file access property list
    # With garbage collection, the other modes don't make sense
    # (Set this first, so that the user-passed properties can overwrite this.)
    fapl["fclose_degree"] = fclose_degree
    fcpl = p_create(H5P_FILE_CREATE, pv...) # file create property list
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

function h5load(src, ::Type{T}, pv...; mode = "r", diskarrays = false, mmaparrays = true, gc = false, ka...) where T
    gc && @eval GC.gc(true)
    fid = h5open(src, mode, pv...; ka...)
    os = Any[]
    fread = diskarrays ? readdisk : !Sys.iswindows() && mmaparrays ? tryreadmmap : read
    for s in fieldnames(T)
        ft = fieldtype(T, s)
        x = if ft <: AbstractArray
            if string(s) ∈ names(fid)
                fread(fid[string(s)])
            else
                zeros(ft.parameters[1], ntuple(i -> 0, ft.parameters[2]))
            end
        else
            x = read_nonarray(fid, string(s))
            x = try ft(x) catch e x end
        end
        push!(os, x)
    end
    obj = T(os...)
    gc && Threads.nthreads() == 1 && finalizer(x -> HDF5.h5_garbage_collect(), obj)
    return obj
end

function h5load(src, paths = nothing, pv...; mode = "r", diskarrays = false, mmaparrays = true, gc = false, ka...)
    gc && @eval GC.gc(true)
    fid = h5open(src, mode, pv...; ka...)
    fread = diskarrays ? readdisk : !Sys.iswindows() && mmaparrays ? tryreadmmap : read
    if isnothing(paths)
        obj = fread(fid)
    elseif paths isa AbstractArray
        obj = Dict(path => fread(fid[path]) for path in paths)
    end
    gc && Threads.nthreads() == 1 && finalizer(x -> HDF5.h5_garbage_collect(), obj)
    return obj
end

h5load(src, path::AbstractString, pv...; ka...) = h5load(src, [path], pv...; ka...)[path]

function h5save(dst, obj, pv...; exclude = [], ka...)
    @eval GC.gc(true)
    h5open(dst, "w", pv...; ka...) do fid
        if obj isa AbstractDict
            for (k, v) in obj
                k ∈ exclude && continue
                write_batch(fid, k, v)
            end
        else
            for s in propertynames(obj)
                s ∈ exclude && continue
                x = getproperty(obj, s)
                if isa(x, AbstractArray)
                    write_batch(fid, string(s), x)
                elseif isa(x, HDF5Dataset)
                    HDF5.create_external(fid, s, filename(x), name(x))
                else
                    write_nonarray(fid, string(s), x)
                end
            end
        end
    end
    return dst
end

h5loadv(a...; ka...) = h5load(a...; fclose_degree = H5F_CLOSE_DEFAULT, ka...)