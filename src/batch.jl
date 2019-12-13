ccount(a) = (ndims(a) == 1 ? length(a) : size(a, ndims(a)))

indbatch(x, b, offset = 0) = (C = ccount(x); min(i + offset, C):min(i + offset + b -1, C) for i in 1:b:C)

function copy_batch!(dst, src)
    dmax = ndims(src) # argmax(size(src))
    mem = prod(size(src)) * sizeof(eltype(src))
    nbatch = ceil(Int,  mem / 1024^3 / 4)
    batchsize = ceil(Int, size(src, dmax) / nbatch)
    @showprogress "copy_batch!" for ts in indbatch(1:size(src, dmax), batchsize)
        inds = ntuple(d -> d == dmax ? ts : (:), ndims(src))
        dst[inds...] = convert(Array, src[inds...])
    end
    return dst
end

function d_zeros(parent, path, T, dims...)
    @assert all(x -> x > 0, dims)
    dst = d_create(parent, path, datatype(T), dataspace(dims))
    copy_batch!(dst, Zeros{T}(dims...))
    return dst
end

function write_batch(parent, name, data)
    has(parent, name) && o_delete(parent, name)
    T, dims = eltype(data), size(data)
    dst = d_create(parent, name, datatype(T), dataspace(dims))
    copy_batch!(dst, data)
    return dst
end

read_nonarray(fid, s) = eval(Meta.parse(String(read(fid["nonarray"][s]))))

function write_nonarray(fid, s, x)
    !exists(fid, "nonarray") && g_create(fid, "nonarray")
    has(fid["nonarray"], s) && o_delete(fid["nonarray"], s)
    fid["nonarray"][s] = isa(x, AbstractString) ? "\"" * x * "\"" : string(x)
end