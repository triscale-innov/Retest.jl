#!/bin/bash
#=
exec julia --project -e "using Retest; Retest.start()"
=#

using Retest
cd(@__DIR__)
try
    include("runtests.jl")
catch err
    showerror(stderr, err)
    print(stderr, "\n")
end

@itest begin
    1 + 1
end

# Local Variables:
# mode: julia
# End:
