function h5load(src, ::Type{T}; mode = "r+", mmaparrays = true) where T
    obj::T = h5open(src, mode) do fid
        o, r = Any[], !Sys.iswindows() && mmaparrays ? readmmap : read
        for s in fieldnames(T)
            ft = fieldtype(T, s)
            if s == :src
                x = src
            elseif ft <: AbstractArray
                x = string(s) ∈ names(fid) ? r(fid[string(s)]) :
                    zeros(ft.parameters[1], ntuple(i -> 0, ft.parameters[2]))
            else
                x = ft(read_nonarray(fid, string(s)))
            end
            push!(o, x)
        end
        T(o...)
    end
    finalizer(x -> HDF5.h5_garbage_collect(), obj)
    return obj
end

function h5save(dst, obj::T; force = false, excludes = []) where T
    isfile(dst) && rm(dst)
    isempty(dst) && error("dst is empty")
    if isdefined(obj, :src) && isfile(obj.src) &&
        splitext(dst)[2] == splitext(obj.src)[2] &&
        !Sys.iswindows() && !force
        symlink(obj.src, dst)
    else
        h5open(dst, "w", "alignment", (0, 8)) do fid
            @showprogress "h5save..." for s in fieldnames(typeof(obj))
                s == :src && continue
                s ∈ excludes && continue
                x = getfield(obj, s)
                if isa(x, AbstractArray)
                    write_batch(fid, string(s), x)
                else
                    write_nonarray(fid, string(s), x)
                end
            end
        end
    end
    return dst
end

h5save(dst, dict::Dict) = h5open(f -> write(f, dict), dst, "w", "alignment", (0, 8))