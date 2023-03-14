using PyCall

pathlib = pyimport("pathlib")

function normalize_path(path::String)
    # expanduser in Julia doesn't expand `~username` expressions, therefore
    # we use the one from Python
    norm_path = path |>  pathlib.posixpath.expanduser |> abspath |> normpath
    if norm_path != "/"
        norm_path = rstrip(norm_path, '/')
    end
    norm_path
end

mutable struct Selection
    path::String

    function Selection()
        storage = "/dev/shm"
        if !isdir(storage)
            storage = "/tmp"
        end
        new(joinpath(storage, "xfiles"))
    end

end

function _read_items(self::Selection)
    open(self.path) do f
        readlines(f)
    end
end

function _write_items(self::Selection, items)
    text = join(items, "\n")
    open(self.path, "w") do f
        write(f, text)
    end
end

function show(self::Selection)
    text = join(_read_items(self), "\n")
    if text != ""
        println(text)
    end
end

function show_path(self::Selection)
    println(self.path)
end

function add(self::Selection, items)
    old_items = _read_items(self)
    all_items = vcat(old_items, items)
    abs_items = [normalize_path(item) for item in all_items if item != ""]
    _write_items(self, unique(abs_items))
end

function remove(self::Selection, items)
    old_items = _read_items(self)
    abs_items = [normalize_path(item) for item in items if item != ""]
    all_items = setdiff(old_items, abs_items)
    _write_items(self, all_items)
end

function clear(self::Selection)
    _write_items(self, [])
end


function get_stdin_args()
    if isa(stdin, Base.TTY)
        stdin_args = []
    else
        stdin_args = filter(!isempty, readlines(stdin))
    end
    return stdin_args
end

function main()

    selection = Selection()
    stdin_args = get_stdin_args()

    if length(ARGS) > 0
        cmd = ARGS[1]
        cmd_args = ARGS[2:end]
        if isempty(cmd_args)
            cmd_args = stdin_args
        end

        if cmd == "+"
            add(selection, cmd_args)
            show(selection)
        elseif cmd == "-"
            remove(selection, cmd_args)
            show(selection)
        elseif cmd == "++"
            show_path(selection)
        elseif cmd == "--"
            clear(selection)
        else
            clear(selection)
            add(selection, ARGS)
            show(selection)
        end

    else
        if length(stdin_args) > 0
            clear(selection)
            add(selection, stdin_args)
        end
        show(selection)
    end
end

main()
