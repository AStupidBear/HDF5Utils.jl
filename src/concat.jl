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

function h5merge(dst, srcs; npart = 100, delete = false, ka...)
    catdir = mkpath(".h5concat_" * randstring())
    @showprogress pmap(enumerate(Iterators.partition(srcs, npart))) do (n, h5s)
        isfile("$catdir/$n.h5") && return
        h5concat("$catdir/$n.h5", h5s; fast = true, ka...)
    end
    h5concat(dst, glob("$catdir/*.h5"); ka...)
    delete && rm(catdir, recursive = true)
end

function h5concat_vds2d(dst, srcs_list; dims = (-2, -1))
    @eval GC.gc(true)
    isfile(dst) && rm(dst)
    isempty(srcs_list) && return
    h5open(dst, "w") do fid
        layout_map, pos_map = Dict(), Dict()
        @showprogress "h5concat.config: " for (i, srcs) in enumerate(srcs_list)
            for (j, src) in enumerate(srcs)
                h5open(src, "r") do fidn
                    for c in names(fidn)
                        if isa(fidn[c], HDF5Dataset)
                            vs = VirtualSource(fidn[c])
                            dims′ = [ifelse(d < 0, ndims(fidn[c]) + d + 1, d) for d in dims]
                            if !haskey(layout_map, c)
                                layout_map[c] = VirtualLayout(fill(0, ndims(fidn[c])), eltype(fidn[c]))
                                pos_map[c] = [0, 0]
                            end
                            layout, pos = layout_map[c], pos_map[c]
                            if j == 1
                                pos[1] = layout.shape[dims′[1]]
                                pos[2] = 0
                            else
                                pos[2] += vs.shape[dims′[2]]
                            end
                            layout.dtype = promote_type(eltype(fidn[c]), layout.dtype)
                            starts = ntuple(ndims(fidn[c])) do d
                                d == dims′[1] ? pos[1] : d == dims′[2] ? pos[2] : 0
                            end
                            layout[[(1:vs.shape[i]) .+ starts[i] for i in 1:ndims(fidn[c])]...] = vs
                        elseif !has(fid, c)
                            o_copy(fidn[c], fid, c)
                        end
                    end
                end
            end
        end
        for c in keys(layout_map)
            d_create_virtual(fid, c, layout_map[c])
        end
    end
    return dst
end

function h5concat_vds(dst, srcs; dims = -1)
    h5concat_vds2d(dst, [srcs]; dims = (-1, dims))
end

h5concat_vds(srcs_list; ka...) = h5concat_vds(randstring() * ".h5", srcs_list; ka...)

h5concat_vds2d(srcs_list; ka...) = h5concat_vds2d(randstring() * ".h5", srcs_list; ka...)