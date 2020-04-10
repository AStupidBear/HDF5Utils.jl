using HDF5Utils
using HDF5
using Glob
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
@test h5load("test.h5") == dict

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

h5concat_vds("concat.h5", repeat(["test.h5"], 100), dim = -2)
@test h5load("concat.h5", virtual = true)["y"] == cat(repeat([data.y], 100)..., dims = 2)

GC.gc(true)
h5open("test.h5", "w") do fid
    fid["x", "compress", 3] = [1 2; 3 4]
end
x = h5load("test.h5")["x"]
@test sum(x) == 10

GC.gc(true)
h5open("vds.h5", "w") do fid
    layout = VirtualLayout((10, sum(1:5)), Float64)
    for i in 1:5
        h5open("vds_$i.h5", "w") do fid′
            fid′["x"] = rand(10, i)
        end
        off = sum(1:i-1)
        layout[:,  (off + 1):(off + i)] = VirtualSource("vds_$i.h5", "x")[:, :]
    end
    d_create_virtual(fid, "x", layout)
end
@test h5load("vds.h5", virtual = true)["x"] ≈ hcat([h5load(h5, virtual = true)["x"] for h5 in glob("vds_*.h5")]...)

foreach(rm, glob("*.h5"))