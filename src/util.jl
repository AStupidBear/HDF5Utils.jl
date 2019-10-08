function HDF5.write(parent::Union{HDF5File, HDF5Group}, data::Dict, plists...)
    for (k, v) in data
        write(parent, k, v, plists...)
    end
end

tryreadmmap(f::Union{HDF5File, HDF5Group}) = Dict(s => tryreadmmap(f[s]) for s in names(f))

HDF5.readmmap(f::Union{HDF5File, HDF5Group}) = Dict(s => readmmap(f[s]) for s in names(f))

function tryreadmmap(obj::HDF5Dataset)
    T = hdf5_to_julia(obj)
    if ismmappable(T) && iscontiguous(obj)
        readmmap(obj, T)
    else
        read(obj, T)
    end
end

Base.lastindex(dset::HDF5Dataset, i) = size(dset, i)

function h5readmmap(filename, name::String, pv...; mode = "r")
    local dat
    fid = h5open(filename, mode, pv...)
    try
        obj = fid[name, pv...]
        dat = readmmap(obj)
    finally
        close(fid)
    end
    dat
end

function HDF5.write(parent::Union{HDF5File, HDF5Group}, name::String, data::Dict, plists...)
    g = g_create(parent, name)
    for (k, v) in data
        write(g, k, v, plists...)
    end
end