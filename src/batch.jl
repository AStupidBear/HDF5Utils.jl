ccount(a) = (ndims(a) == 1 ? length(a) : size(a, ndims(a)))

indbatch(x, b, offset = 0) = (C = ccount(x); min(i + offset, C):min(i + offset + b -1, C) for i in 1:b:C)

macro pthreads(flag, ex)
    esc(:($flag ? Threads.@threads($ex) : $ex))
end

function copy_batch!(dest, src; desc = "copy_batch: ")
    @assert !isempty(src)
    dmax = ndims(src) # argmax(size(src))
    mem = prod(size(src)) * sizeof(eltype(src))
    batchmem = min(4096, Sys.total_memory() / 1024^2 / 5)
    nbatch = ceil(Int,  mem / 1024^2 / batchmem)
    batchsize = ceil(Int, size(src, dmax) / nbatch)
    slices = collect(indbatch(1:size(src, dmax), batchsize))
    p = Progress(length(slices), desc = desc)
    flag = isa(dest, AbstractArray)
    @pthreads flag for slice in slices
        is = ntuple(d -> d == dmax ? slice : (:), ndims(src))
        dest[is...] = convert(Array, src[is...])
        next!(p)
    end
    return dest
end

function d_zeros(parent, path, T, dims, a...)
    has(parent, path) && o_delete(path)
    @assert all(x -> x > 0, dims)
    dset = d_create(parent, path, datatype(T), dataspace(dims), a...)
    copy_batch!(dset, Zeros{T}(dims...), desc = "zeros.$path ")
    flush(dset)
    return dset
end

function write_batch(parent, name, data, a...)
    has(parent, name) && o_delete(parent, name)
    T, dims = eltype(data), size(data)
    if Threads.nthreads() > 1
        dset = d_zeros(parent, name, T, dims, a...)
        arr = readmmap(dset)
        copy_batch!(arr, data, desc = "write.$name ")
        Mmap.sync!(arr)
    else
        dset = d_create(parent, name, datatype(T), dataspace(dims), a...)
        copy_batch!(dset, data, desc = "write.$name ")
    end
end

read_nonarray(fid, s) = eval(Meta.parse(String(read(fid["nonarray"][s]))))

function write_nonarray(fid, s, x)
    !exists(fid, "nonarray") && g_create(fid, "nonarray")
    has(fid["nonarray"], s) && o_delete(fid["nonarray"], s)
    fid["nonarray"][s] = isa(x, AbstractString) ? "\"" * x * "\"" : string(x)
end