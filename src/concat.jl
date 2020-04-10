 function h5concat(dst, srcs; dim = 1, fast = false)
    isfile(dst) && rm(dst)
    isempty(srcs) && return
    h5open(dst, "w", "alignment", (0, 8)) do fid
        type_map, size_map, pos_map, dims = Dict(), Dict(), Dict(), Dict()
        @showprogress "h5concat.config: " for src in srcs
            h5open(src, "r") do fidn
                for c in names(fidn)
                    if isa(fidn[c], HDF5Dataset)
                        pos_map[c] = 0
                        type_map[c] = promote_type(eltype(fidn[c]), Float32)
                        if haskey(size_map, c)
                            for d in eachindex(size_map[c])
                                if d == dims[c]
                                    size_map[c][d] += size(fidn[c], d)
                                else
                                    size_map[c][d] = min(size_map[c][d], size(fidn[c], d))
                                end
                            end
                        else
                            dims[c] = dim > 0 ? dim : (ndims(fidn[c]) + 1 + dim)
                            size_map[c] = collect(size(fidn[c]))
                        end
                    elseif !has(fid, c)
                        o_copy(fidn[c], fid, c)
                    end
                end
            end
        end
        @showprogress "h5concat.init: " for c in keys(type_map)
            d_zeros(fid, c, type_map[c], size_map[c])
        end
        if !fast
            for src in srcs
                h5open(src, "r") do fidn
                    name = basename(src)
                    @showprogress "h5concat.$name: " for c in keys(type_map) ∩ names(fidn)
                        ends = pos_map[c] + size(fidn[c], dims[c])
                        ind = (pos_map[c] + 1):min(ends, size_map[c][dims[c]])
                        indn = ind .- pos_map[c]
                        inds = ntuple(d -> d == dims[c] ? ind : (1:size_map[c][d]), ndims(fidn[c]))
                        indns = ntuple(d -> d == dims[c] ? indn : (1:size_map[c][d]), ndims(fidn[c]))
                        if all(!isempty, indns)
                            fid[c][inds...] = fidn[c][indns...]
                            pos_map[c] = last(ind)
                        end
                    end
                end
            end
        else
            xs, fids = [], h5open.(srcs, "r")
            try
                for c in keys(type_map)
                    x = read(fid[c])
                    @showprogress "h5concat.$c: " for fidn in fids
                        ends = pos_map[c] + size(fidn[c], dims[c])
                        ind = (pos_map[c] + 1):min(ends, size_map[c][dims[c]])
                        indn = ind .- pos_map[c]
                        inds = ntuple(d -> d == dims[c] ? ind : (1:size_map[c][d]), ndims(fidn[c]))
                        indns = ntuple(d -> d == dims[c] ? indn : (1:size_map[c][d]), ndims(fidn[c]))
                        if all(!isempty, indns)
                            x[inds...] = fidn[c][indns...]
                            pos_map[c] = last(ind)
                        end
                    end
                    copy_batch!(fid[c], x)
                end
            finally
                foreach(close, fids)
                @eval GC.gc()
            end
        end
    end
    return dst
end

function h5concat_bigdata(dst, srcs; npart = 100, delete = false, ka...)
    catdir = mkpath(".h5concat_" * randstring())
    @showprogress pmap(enumerate(Iterators.partition(srcs, npart))) do (n, h5s)
        isfile("$catdir/$n.h5") && return
        h5concat("$catdir/$n.h5", h5s; fast = true, ka...)
    end
    h5concat(dst, glob("$catdir/*.h5"); ka...)
    delete && rm(catdir, recursive = true)
end

function h5concat_vds(dst, srcs; dim = 1, reduceop = max)
    @eval GC.gc(true)
    isfile(dst) && rm(dst)
    isempty(srcs) && return
    h5open(dst, "w") do fid
        type_map, size_map, pos_map, dims = Dict(), Dict(), Dict(), Dict()
        @showprogress "h5concat.config: " for src in srcs
            h5open(src, "r") do fidn
                for c in names(fidn)
                    if isa(fidn[c], HDF5Dataset)
                        pos_map[c] = 0
                        type_map[c] = promote_type(eltype(fidn[c]), Float32)
                        if haskey(size_map, c)
                            for d in eachindex(size_map[c])
                                if d == dims[c]
                                    size_map[c][d] += size(fidn[c], d)
                                else
                                    size_map[c][d] = reduceop(size_map[c][d], size(fidn[c], d))
                                end
                            end
                        else
                            dims[c] = dim > 0 ? dim : (ndims(fidn[c]) + 1 + dim)
                            size_map[c] = collect(size(fidn[c]))
                        end
                    elseif !has(fid, c)
                        o_copy(fidn[c], fid, c)
                    end
                end
            end
        end
        layout_map = Dict(c => VirtualLayout(size_map[c], type_map[c]) for c in keys(type_map))
        @showprogress "h5concat.layout: " for src in srcs
            h5open(src, "r") do fidn
                for c in keys(type_map) ∩ names(fidn)
                    vs = VirtualSource(fidn[c])
                    ends = pos_map[c] + size(fidn[c], dims[c])
                    ind = (pos_map[c] + 1):min(ends, size_map[c][dims[c]])
                    indn = ind .- pos_map[c]
                    inds = ntuple(d -> d == dims[c] ? ind : (1:size_map[c][d]), ndims(fidn[c]))
                    indns = ntuple(d -> d == dims[c] ? indn : (1:size_map[c][d]), ndims(fidn[c]))
                    if all(!isempty, indns)
                        layout_map[c][inds...] = vs[indns...]
                        pos_map[c] = last(ind)
                    end
                end
            end
        end
        for c in keys(type_map)
            d_create_virtual(fid, c, layout_map[c])
        end
    end
    return dst
end