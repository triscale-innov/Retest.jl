module Retest

export @retest, @itest

macro retest(dir)
    quote
        using Revise
        using Jive

        import REPL.Terminals
        terminal = Terminals.TTYTerminal("", stdin, stdout, stderr)

        watch($dir; sources=[normpath(joinpath($dir, "..", "src"))]) do path
            fname = splitdir(path)[end]
            startswith(fname, ".#") && return
            endswith(fname, "~")    && return

            Terminals.clear(terminal)
            @info "File changed" path
            revise()
            include("runtests.jl")
        end

        try
            include("runtests.jl")
        catch e
            msg = e.error
            @warn "Tests failed" msg
        end
    end |> esc
end

macro itest(expr)
    aux(x) = deepcopy(x)
    aux(e::Expr) = if e.head == :macrocall
        Expr(e.head, e.args[1], nothing, aux.(filter(x->!isa(x, LineNumberNode), e.args[3:end]))...)
    else
        Expr(e.head, aux.(filter(x->!isa(x, LineNumberNode), e.args))...)
    end

    expr2 = if expr.head == :block
        expr
    else
        quote $expr end
    end

    quote
        println()
        println("Interactive test:")
        $(Meta.quot(aux(expr2))) |> display
        println()
        $(esc(expr)) |> display
        println()
    end
end

end # module
