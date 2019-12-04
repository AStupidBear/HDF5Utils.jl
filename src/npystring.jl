import .PyCall: PyObject, NpyArray, npy_type, NPY_STRING, @npyinitialize, @pycheck
import .PyCall: npy_api, NPY_ARRAY_ALIGNED, NPY_ARRAY_WRITEABLE, array2py, PyPtr

npy_type(::Type{T}) where T <: MaxLenString = NPY_STRING

function NpyArray(a::StridedArray{T}, revdims::Bool) where T <: MaxLenString
    @npyinitialize
    size_a = revdims ? reverse(size(a)) : size(a)
    strides_a = revdims ? reverse(strides(a)) : strides(a)
    p = @pycheck ccall(npy_api[:PyArray_New], PyPtr,
          (PyPtr, Cint, Ptr{Int}, Cint, Ptr{Int}, Ptr{T}, Cint, Cint, PyPtr),
          npy_api[:PyArray_Type],
          ndims(a), Int[size_a...], npy_type(T),
          Int[strides_a...] * sizeof(eltype(a)), a, sizeof(eltype(a)),
          NPY_ARRAY_ALIGNED | NPY_ARRAY_WRITEABLE,
          C_NULL)
    return PyObject(p, a)
end

function PyObject(a::StridedArray{T}) where T <: MaxLenString
    try
        return NpyArray(a, false)
    catch
        return array2py(a) # fallback to non-NumPy version
    end
end