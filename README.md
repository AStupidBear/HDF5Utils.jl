# Extensions to HDF5.jl

## Installation

```jl
using Pkg
pkg"add HDF5Utils"
```

## Usage

```jl
using HDF5, HDF5Utils
```

Save data with 8-byte alignment for reading back later using mmap.

```jl
h5save("test.h5", Dict("x" => UInt8[0], "y" => Float64[0]))
h5open(tryreadmmap, "test.h5")
```

Convert String to MaxLenString to save space.

```jl
MLString{5}.(["a", "b"])
```

Save MaxLenString as HDF5's fixed size string. 

```jl
h5save("test.h5", Dict("x" => MLString{5}["α" "β"; "γ" "δ"]))
```
Save NamedTuple as HDF5's compound.

```jl
h5save("test.h5", Dict("x" => [(a = 1, b = 1f0)]))
```

Concatenate datasets in multiple HDF5 files along a given dimension (`-2` represents `end - 1`).

```jl
h5concat("concat.h5", repeat(["test.h5"], 100), dim = -2)
```