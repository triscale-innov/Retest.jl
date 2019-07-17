# Retest.jl

![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)

## Installation

```
] add https://github.com/triscale-innov/Retest.jl.git
```

## Usage

First, your project must follow the standard files hierarchy:

- Project/
  - Project.toml
  - Manifest.toml
  - src/
      - Project.jl
      - other.jl
      - ...
  - test/
      - runtests.jl
      - ...

In particular, everything should be set up so that the project tests can be run
in the following way:

```
sh$ cd Project/test
sh$ julia --project runtests.jl
```


If everything is setup in this way, using `Retest` is straightforward. Just add
a `Project/test/retest.jl` script file with the following contents:

```julia
#!/bin/bash
#=
exec julia --project --color=yes -qi retest.jl
=#

using Pkg
cd(@__DIR__)
Pkg.activate("..")

using Retest
@retest(@__DIR__)
```

Running this script will open a Julia REPL in which your tests results will be
updated as source files change in the project:

```
sh$ cd path/to/Project/test
sh$ ./retest.jl
```

Alternatively, just `include` this script from a running REPL (*e.g.* in Juno or
VScode):

```
julia> include("path/to/Project/test/retest.jl")
```
