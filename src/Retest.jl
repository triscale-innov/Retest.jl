module Retest

using Jive
export @retest, @itest, restart

macro retest(dir)
    quote
        import Revise
        import Jive
        import REPL

        let terminal = REPL.Terminals.TTYTerminal("", stdin, stdout, stderr)
            REPL.Terminals.clear(terminal)
            Jive.watch($dir; sources=[normpath(joinpath($dir, "..", "src"))]) do path
                fname = splitdir(path)[end]
                startswith(fname, ".#") && return
                endswith(fname, "~")    && return

                REPL.Terminals.clear(terminal)
                @info "File changed" path
                Revise.revise()
                include("runtests.jl")
                REPL.LineEdit.refresh_line(Base.active_repl.mistate)
            end
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

function restart()
    Jive.stop(Jive.watch)
    atexit(()->run(`julia --color=yes -qi retest.jl`))
    println("Restarting...")
    exit()
end

end # module
