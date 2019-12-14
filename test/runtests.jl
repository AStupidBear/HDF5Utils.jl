using HDF5Utils
using HDF5
using Test

cd(mktempdir())

dict = Dict(
    "str" => "abcdef",
    "mlstr" => s10"北京欢迎你",
    "nt" => (α = 1, β = 2, γ = s3"β"),
    "longstr" => string(rand(100)),
    "arr[uint8]" => zeros(UInt8, 7),
    "arr[mlstr]" => MLString{5}["α" "β"; "γ" "δ"],
    "arr[nt]" => repeat([(a = 1, b = s4"α", c = 1f0)], 2),
    "group" => Dict(
        "arr[float32]" => zeros(Float32, 10),
        "group" => Dict("arr[float64]" => ones(10)),
        )
    )
h5save("test.h5", dict)
@test h5open(read, "test.h5") == dict
@test h5open(tryreadmmap, "test.h5") == dict

mutable struct Data
    x::Array{Float32, 2}
    y::Array{Float64, 3}
    z::Dict{String, Int}
    w::String
end
data = Data(rand(Float32, 2, 2), rand(2, 2, 2), Dict("a" => 1), "abcd")
h5save("test.h5", data)
data′ = h5load("test.h5", Data)
for s in fieldnames(Data)
    @test getfield(data, s) == getfield(data′, s)
end

h5concat("concat.h5", repeat(["test.h5"], 100), dim = -2)
@test h5load("concat.h5", Data).y == cat(repeat([data.y], 100)..., dims = 2)

h5concat_bigdata("concat.h5", repeat(["test.h5"], 100), npart = 10, dim = 1, delete = true)
@test h5load("concat.h5", Data).y == vcat(repeat([data.y], 100)...)

rm("test.h5")
rm("concat.h5")

# using HDF5, HDF5Utils, Mmap
# h5open("test.h5", "w", "alignment", (0, 8)) do fid
#     # fid["a"] = [1, 2]
#     # x = readmmap(fid["a"])
#     # x[1] = 11
#     # Mmap.sync!(x)
#     # dset = d_zeros(fid, "a", Float32, 10, 10)
#     d_create(fid, "a", HDF5.datatype(Float32), HDF5.dataspace((10, 10)))
#     fid["a"][:, :] = zeros(10, 10)
#     HDF5.flush(fid["a"])
#     # fid["a"] = zeros(10, 10)
#     dset = fid["a"]
#     # dset[:, :] = 2
#     arr = readmmap(dset)
#     arr[1] = 100
#     # copy_batch!(arr, data)
#     # write_batch(fid, "a", [1, 2])
#     return nothing
# end
# dict = h5open(readmmap, "test.h5",  "r+")