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
    "arr[mlstr]" => MLString{16}["α" "β"; "γ" "δ"] |> vec,
    "arr[nt]" => repeat([(a = 1, b = s4"α", c = 1f0)], 2),
    "group" => Dict(
        "arr[float32]" => zeros(Float32, 10),
        "group" => Dict("arr[float64]" => ones(10)),
        )
    )
h5save("test.h5", dict)
@test h5open(read, "test.h5") == dict
@test h5open(tryreadmmap, "test.h5") == dict
@test h5load("test.h5") == dict

mutable struct Data
    x::Array{Float32, 2}
    y::Array{Float64, 3}
    z::Array{Float64, 3}
    a::Dict{String, Int}
    b::String
end
x = rand(Float32, 20, 30)
y = rand(20, 30, 40)
z = rand(20, 30, 40)
data = Data(x, y, z, Dict("a" => 1), "abcd")
h5save("data.h5", data)
data′ = h5load("data.h5", Data)
for s in fieldnames(Data)
    @test getfield(data, s) == getfield(data′, s)
end
data′ = 0

for v in (false, true)
    file = "vconcat_$v.h5"
    h5concat("vconcat_$v.h5", ["data.h5", "data.h5"], dims = -2, virtual = v)
    h5concat!("vconcat_$v.h5", "q", r"y|z"; dims = 1, virtual = v)
    @test h5loadv("vconcat_$v.h5", "y") ≈ repeat(y, outer = (1, 2, 1))
    @test h5loadv("vconcat_$v.h5", "q") ≈ cat([repeat(a, outer = (1, 2, 1)) for a in (y, z)]..., dims = 1)
    srcs_list = [["data.h5", "data.h5"], ["data.h5"], ["data.h5", "data.h5", "data.h5"]]
    h5concat("vconcat2d_$v.h5", srcs_list, dims = (-2, -1), virtual = v)
    @test h5loadv("vconcat2d_$v.h5", "x") ≈ [x x zero(x); x zero(x) zero(x); x x x]
end

h5open("compress.h5", "w") do fid
    fid["x", "compress", 3] = [1 2; 3 4]
end
@test sum(h5load("compress.h5", "x")) == 10

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
h5concat("vdscat.h5", ["vds_$i.h5" for i in 1:5], dims = -1)
@test h5loadv("vdscat.h5", "x") ≈ hcat([h5loadv(h5, "x") for h5 in glob("vds_*.h5")]...)
@test h5loadv("vds.h5", "x") ≈ hcat([h5loadv(h5, "x") for h5 in glob("vds_*.h5")]...)

function sumloop(x)
    s = 0.0
    @inbounds for i in eachindex(x)
        s += x[i]
    end
    return s
end

for d in 1:3
    for n in (10, 100, 200, 500, 10^7)
        GC.gc(true)
        exp(d * log(n)) * 8 > 1024^3 && continue
        h5open("disk_$(d)_$n.h5", "w") do fid
            chunk = ntuple(i -> min(n, 100), d)
            x = rand(fill(n, d)...)
            fid["x", "chunk", chunk] = x
        end
        x = h5load("disk_$(d)_$n.h5", "x")
        sum(read(x.ds)), sumloop(x)
        t_cache = @elapsed s_cache = sumloop(x)
        t_read = @elapsed s_read = sum(read(x.ds))
        @show n, d, t_cache / t_read
        @test s_read ≈ s_cache
    end
end

foreach(rm, glob("*.h5"))