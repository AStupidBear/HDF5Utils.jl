function _h5concat2d(dst, srcs_list, pv...; dims, virtual = true, ka...)
    isfile(dst) && rm(dst)
    @eval GC.gc(true)
    h5open(dst, "w", pv...; ka...) do fid
        layout_map, pos_map = Dict(), Dict()
        @showprogress "h5concat.config: " for (i, srcs) in enumerate(srcs_list)
            for (j, src) in enumerate(srcs)
                fidn = h5open(src, "r", pv...; ka...)
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
                            pos[1] = dims′[1] == 0 ? 0 : layout.shape[dims′[1]]
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
                close(fidn)
            end
        end
        for c in keys(layout_map)
            d_create_virtual(fid, c, layout_map[c])
        end
    end
    return dst
end

function h5concat(dst, srcs, pv...; dims, virtual = true, ka...)
    if length(dims) == 1
        srcs, dims = [srcs], (0, dims)
    end
    _h5concat2d(dst, srcs, pv...; dims = dims, virtual = virtual, ka...)
end

h5concat(srcs, pv...; ka...) = h5concat(randstring() * ".h5", srcs, pv...; ka...)

function h5concat!(h5, name, pattern, pv...; dims, virtual = true, ka...)
    @eval GC.gc(true)
    h5open(h5, "r+", pv...; fclose_degree = H5F_CLOSE_DEFAULT, ka...) do fid
        layout = nothing
        for c in names(fid)
            !occursin(pattern, c) && continue
            !isa(fid[c], HDF5Dataset) && continue
            vs = VirtualSource(fid[c])
            if isnothing(layout)
                layout = VirtualLayout(fill(0, ndims(fid[c])), eltype(fid[c]))
            end
            dims′ = dims < 0 ? ndims(fid[c]) + dims + 1 : dims
            layout.dtype = promote_type(eltype(fid[c]), layout.dtype)
            starts = ntuple(ndims(fid[c])) do d
                d == dims′ ? layout.shape[dims′] : 0
            end
            layout[[(1:vs.shape[i]) .+ starts[i] for i in 1:ndims(fid[c])]...] = vs
        end
        !isnothing(layout) && d_create_virtual(fid, name, layout, virtual)
    end
    return h5
end