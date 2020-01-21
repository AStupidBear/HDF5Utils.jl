using Base: between, @propagate_inbounds

struct MaxLenString{N} <: AbstractString
    data::NTuple{N, UInt8}
    MaxLenString{N}(itr) where {N} = new(NTuple{N, UInt8}(itr))
end

const MLString = MaxLenString

MaxLenString(s::AbstractString) = MaxLenString{sizeof(s)}(Vector{UInt8}(s))

function MaxLenString{N}(s::AbstractString) where N
    data = resize!(Vector{UInt8}(s), N)
    data[(sizeof(s) + 1):N] .= 0x00
    MaxLenString{N}(data)
end

function Base.convert(::Type{String}, s::MaxLenString)
    p = pointer(collect(s.data))
    if s.data[end] == 0x00
        unsafe_string(p)
    else
        unsafe_string(p, sizeof(s))
    end
end

Base.String(s::MaxLenString) = convert(String, s)

Base.show(io::IO, mime::MIME"text/plain", s::MaxLenString) = show(io, mime, String(s))

Base.show(io::IO, s::MaxLenString) = show(io, String(s))

@propagate_inbounds function Base.iterate(s::MaxLenString, i::Int=firstindex(s))
    i > ncodeunits(s) && return nothing
    b = codeunit(s, i)
    u = UInt32(b) << 24
    between(b, 0x80, 0xf7) || return reinterpret(Char, u), i+1
    return next_continued(s, i, u)
end

function next_continued(s::MaxLenString, i::Int, u::UInt32)
    u < 0xc0000000 && (i += 1; @goto ret)
    n = ncodeunits(s)
    # first continuation byte
    (i += 1) > n && @goto ret
    @inbounds b = codeunit(s, i)
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b) << 16
    # second continuation byte
    ((i += 1) > n) | (u < 0xe0000000) && @goto ret
    @inbounds b = codeunit(s, i)
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b) << 8
    # third continuation byte
    ((i += 1) > n) | (u < 0xf0000000) && @goto ret
    @inbounds b = codeunit(s, i)
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b); i += 1
    @label ret
    return reinterpret(Char, u), i
end

Base.lastindex(s::MaxLenString{N}) where {N} = N

Base.getindex(s::MaxLenString, i::Int) = Char(s.data[i])

Base.sizeof(s::MaxLenString) = sizeof(s.data)

Base.length(s::MaxLenString) = length(s.data)

Base.ncodeunits(s::MaxLenString) = length(s.data)

Base.codeunit(::MaxLenString) = UInt8
Base.codeunit(s::MaxLenString, i::Integer) = s.data[i]

Base.isvalid(s::MaxLenString, i::Int) = checkbounds(Bool, s, i)

function Base.read(io::IO, T::Type{MaxLenString{N}}) where N
    return read!(io, Ref{T}())[]::T
end

function Base.write(io::IO, s::MaxLenString{N}) where N
    return write(io, Ref(s))
end

for n in 2:20
    msym = Symbol("s$(n)_str")
    emsym = Symbol("@s$(n)_str")
    @eval export $emsym
    @eval macro $msym(str)
        MaxLenString{$n}(str)
    end
end

function HDF5.hdf5_type_id(::Type{T}) where T <: MaxLenString
    type_id = h5t_copy(hdf5_type_id(String))
    h5t_set_size(type_id, sizeof(T))
    cset = get(ENV, "CSET", string(H5T_CSET_UTF8))
    h5t_set_cset(type_id, parse(Int, cset))
    return type_id
end

Base.zero(::Type{T}) where T <: MaxLenString = T("")

Base.zero(::T) where T <: MaxLenString = T("")

@h5bitslike MaxLenString

for f in [:(==), :(<=), :(>=), :<, :>, :isless, :isequal]
    @eval Base.$f(x::MaxLenString, y::MaxLenString) = $f(x.data, y.data)
end

for N in [4, 8, 16]
    I = Meta.parse(string("UInt", 8N))
    @eval function Base.unique(x::AbstractArray{T}) where T <: MaxLenString{$N}
        reinterpret(T, unique(reinterpret($I, x)))
    end
    @eval function Base.sort(x::AbstractArray{T}; ka...) where T <: MaxLenString{$N}
        reinterpret(T, sort(reinterpret($I, x); ka...))
    end
end

Base.hash(x::MaxLenString) = hash(x.data)