module Internal

import Pkg
import Revise
import Dates
import REPL

import ..SandBox

struct Event
    typ :: Symbol
    val :: String
end
Event(typ) = Event(typ, "")

const PACKAGE     = Module[]
const ENTRY_POINT = Ref("")
const FILES       = Set{String}()
const TASKS       = Dict{String,Task}()
const CHANNEL     = Channel{Event}()

module Sandbox

end

function start(entry_point; inner=false)
    projname = Pkg.project().name |> Symbol
    prog = quote
        using Revise
        using Retest
        using $projname
        Retest.Internal.retest($projname, $entry_point)
    end |> string

    julia = Base.julia_cmd()[1]

    err = true
    try
        run(`$julia -qi --project --color=yes -e $prog`)
        err = false
    catch
    end

    if err
        inner && exit(1)
        error("[Retest] Subprocess failed")
    else
        inner && exit(0)
        @info "[Retest] Ending session"
    end
end

function restart()
    pause()
    @info "[Retest] Restarting..."
    start(ENTRY_POINT[] ; inner=true)
end

function retest(package, entry_point)
    empty!(PACKAGE); push!(PACKAGE, package)
    ENTRY_POINT[] = abspath(entry_point)
    resume()
end

function resume()
    # retest should have been run beforehand
    @assert length(PACKAGE) == 1
    package = PACKAGE[1]

    @assert ENTRY_POINT[] != ""
    entry_point = ENTRY_POINT[]

    if isactive()
        @warn "[Retest] No need to resume: main task already active"
        return
    end

    # empty!(CHANNEL)
    while isready(CHANNEL); popfirst!(CHANNEL); end

    TASKS[""] = @async begin
        main_loop(package, entry_point)
        @info "[Retest] Stopped"
    end

    nothing
end

function main_loop(package, entry_point)
    terminal = REPL.Terminals.TTYTerminal("", stdin, stdout, stderr)

    # Wait for the prompt to appear before clearing the terminal
    sleep(0.05)
    clear(terminal)
    @info "[Retest] Started" package entry_point

    # Run the provided test script
    # This starts populating FILES
    include_entry_point()

    while true
        # At this stage, FILES contains `entry_point` and all files included
        # from it. Add files from the module.
        id = Revise.PkgId(package)
        pkgdata = Revise.pkgdatas[id]
        for file in Revise.srcfiles(pkgdata)
            push!(FILES, joinpath(Revise.basedir(pkgdata), file))
        end

        # Ensure all necessary files are watched
        for file in FILES
            isactive(file) || (TASKS[file] = @async watch_file(file))
        end

        # GC: stop tracking unnecessary done tasks
        for file in keys(TASKS)
            file == ""    && continue
            file in FILES && continue
            if istaskdone(TASKS[file])
                delete!(TASKS, file)
            end
        end

        # Wait for an event. Immediately handle :stop requests.
        evt = popfirst!(CHANNEL)
        evt.typ == :stop && return

        # Otherwise, collect events occurring shortly afterwards.
        clear(terminal)
        sleep(0.1)
        while true
            if evt.typ == :change
                @info "[Retest] Detected change" date = Dates.now() file=evt.val
            elseif evt.typ == :trigger
                @info "[Retest] Triggered update" date = Dates.now()
            else
                @warn "[Retest] Unknown event" event=evt
            end

            isready(CHANNEL) || break
            evt = popfirst!(CHANNEL)
            evt.typ == :stop && return
        end

        # Run the provided test script
        # This starts populating FILES
        include_entry_point()
    end
end

function watch_file(file)
    while isactive() && file in FILES
        ret = Revise.FileWatching.watch_file(file)
        if isactive() && file in FILES && (ret.changed || ret.renamed)
            put!(CHANNEL, Event(:change, file))
            sleep(1)
        end
    end
end

function isactive(key="")
    haskey(TASKS, key) || return false

    t = TASKS[key]
    !(istaskdone(t) || istaskfailed(t))
end

function include_entry_point()
    i = length(Revise.included_files)
    empty!(FILES)

    try
        Revise.revise()
        quote
            include($(ENTRY_POINT[]))
        end |> SandBox.eval
    catch err
        @warn "[Retest] Error" err
    end

    while i < length(Revise.included_files)
        i += 1
        push!(FILES, Revise.included_files[i][2])
    end

    println()
    REPL.LineEdit.refresh_line(Base.active_repl.mistate)
end

function pause()
    if isactive()
        put!(CHANNEL, Event(:stop))
    end
    if haskey(TASKS, "")
        wait(TASKS[""])
    end
end

function trigger()
    @async begin
        sleep(0.01)
        put!(CHANNEL, Event(:trigger))
    end
    nothing
end

function status()
    for file in sort!(collect(keys(TASKS)))
        task = TASKS[file]
        stat = if !istaskstarted(task)
            "S" # Started
        elseif istaskfailed(task)
            "E" # Error
        elseif istaskdone(task)
            "D" # Done
        else
            "R" # Running
        end

        if file == ""
            file = "[MAIN TASK]"
            watched = "+"
        else
            watched = file in FILES ? "+" : "-"
        end

        println("$stat$watched $file")
        if istaskfailed(task)
            try
                wait(task)
            catch err
                buf = IOBuffer()
                showerror(buf, err)
                msg = String(take!(buf))
                print(" "^5)
                replace(msg, "\n" => "\n" * " "^5) |> println
            end
        end
    end
end

function clear(terminal)
    println("^L")
    REPL.Terminals.clear(terminal)
end

end # module Internal
