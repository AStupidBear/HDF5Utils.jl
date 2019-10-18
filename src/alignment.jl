h5p_set_alignment(plist_id, threshold, alignment) = 
    ccall((:H5Pset_alignment, libhdf5), Herr, (Hid, Hsize, Hsize), plist_id, threshold, alignment)

h5p_get_alignment(plist_id, threshold, alignment) =
    ccall((:H5Pget_alignment, libhdf5), Herr, (Hid, Ptr{Hsize}, Ptr{Hsize}), plist_id, threshold, alignment)

function get_alignment(plist_id)
    threshold = Ref{Hsize}()
    alignment = Ref{Hsize}()
    h5p_get_alignment(plist_id, threshold, alignment)
    return threshold[], alignment[]
end

@init HDF5.hdf5_prop_get_set["alignment"] = (nothing, h5p_set_alignment, H5P_FILE_ACCESS)