h5p_set_alignment(plist_id, threshold, alignment) = ccall((:H5Pset_alignment, libhdf5), Herr, (Hid, Hsize, Hsize), plist_id, threshold, alignment)

@init HDF5.hdf5_prop_get_set["alignment"] = (nothing, h5p_set_alignment, H5P_FILE_ACCESS)