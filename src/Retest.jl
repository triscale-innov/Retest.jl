module Retest

# Tests will be evaluated in this module
module SandBox
using Retest
end

include("Internal.jl")

export @itest
# export restart, pause, resume, trigger, status, reload

"""
    start(entry_point="runtests.jl")

Start a new interactive Retest REPL, in which both the current project and the
provided entry_point will be watched for changes. Every time a watched source
file changes, the script provided by the entry_point gets run again.
"""
start(entry_point="retest.jl") = Internal.start(entry_point)


"""
    pause()

Stop watching files and re-running tests. Retest can be resumed using the
`Retest.resume()` function.
"""
pause() = Internal.pause()


"""
    resume()

Resume the Retest task after it has been stopped using `Retest.pause()`.
"""
resume() = Internal.resume()


"""
    trigger()

Trigger re-running the tests, as if a change had been detected in one of the
watched files.
"""
trigger() = Internal.trigger()


"""
    status()

See the list of currently watched files, and the status of tasks watching them.
"""
status() = Internal.status()


"""
    restart()

Stop the current Retest REPL, and start a new one. This is useful in order to
account for changes that Revise cannot track.
"""
restart() = Internal.restart()


"""
    reload()

Pause the current Retest REPL, and immediately resume it. This is only useful
for testing Retest itself.
"""
function reload()
    Internal.pause()
    Internal.resume()
end


"""
    @itest expr

Display `expr`, evaluate its result, and display it as if it had been entered in
the REPL.
"""
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
