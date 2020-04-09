function h5load(src, ::Type{T}; mode = "r+", mmaparrays = true) where T
    fid = h5open(src, mode)
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
    finalizer(x -> close(fid), obj)
    finalizer(x -> HDF5.h5_garbage_collect(), obj)
    return obj
end

function h5load(src; mode = "r+", mmaparrays = true)
    fid = h5open(src, mode)
    obj = !Sys.iswindows() && mmaparrays ? tryreadmmap(fid) : read(fid)
    finalizer(x -> close(fid), obj)
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
    end
    return dst
end

h5save(dst, dict::Dict) = h5open(f -> write(f, dict), dst, "w", "alignment", (0, 8))