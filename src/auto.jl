function h5e_get_auto(estack_id, func, client_data)
    ccall((:H5Eget_auto2, libhdf5), Herr, (Hid, Ptr{Ptr{Nothing}}, Ptr{Ptr{Nothing}}), estack_id, func, client_data)
end

function h5e_set_auto(estack_id, func, client_data)
    ccall((:H5Eset_auto2, libhdf5), Herr, (Hid, Ptr{Nothing}, Ptr{Nothing}), estack_id, func, client_data)
end

function e_get_auto()
    errfunc = Ref(Ptr{Nothing}())
    errdata = Ref(Ptr{Nothing}())
    h5e_get_auto(HDF5.H5E_DEFAULT, errfunc, errdata)
    return errfunc[], errdata[]
end

function e_set_auto(errfunc, errdata)
    h5e_set_auto(HDF5.H5E_DEFAULT, errfunc, errdata)
end

const _errfunc = Ref(Ptr{Nothing}())
const _errdata = Ref(Ptr{Nothing}())

function disable_dag()
    if _errfunc[] == C_NULL
        _errfunc[], _errdata[] = e_get_auto()
    end
    e_set_auto(C_NULL, C_NULL)
end

function enable_dag()
    e_set_auto(_errfunc[], _errdata[])
end
