#!/usr/bin/env lua5.4

fs = require 'lfs'
posix = require 'posix'

local pathSep = "/"

local function isWritableDir(path)
   -- Source: https://stackoverflow.com/a/40195356
   dir = path.."/" -- "/" works on both Unix and Windows
   local ok, err, code = os.rename(dir, dir)
   return ok
end


local function normalizePath(path)

    local function split(text, separator)
        local parts = {}
        local index = 0
        while true do
            start = index + 1
            index = string.find(text, separator, start)
            if index then
                table.insert(parts, string.sub(text, start, index-1))
            else
                table.insert(parts, string.sub(text, start, #text))
                break
            end
        end
        return parts
    end

    local function merge(dst, src)
        -- merge tables
        for _, item in pairs(src) do
            table.insert(dst, item)
        end
    end

    local function compress(t)
        -- assign consecutive indices to the values
        local new = {}
        for _, v in pairs(t) do
            table.insert(new, v)
        end
        return new
    end

    local parts = split(path, pathSep)

    local function getHomeDir(user)
        local user_info
        if user == "" then
            user_info = posix.getpwuid(posix.getuid())
        else
            user_info = posix.getpwnam(user)
        end
        return user_info.pw_dir
    end

    local function expandHomeDir(parts)
        -- note ~root notation
        if string.sub(parts[1], 1, 1) == "~" then
            local user = string.sub(parts[1], 2, -1)
            local home = getHomeDir(user)
            local prefix = split(home, pathSep)
            parts[1] = nil
            parts = compress(parts)
            merge(prefix, parts)
            parts = prefix
        end
        return parts
    end

    local function relativeToAbsolute(parts)
        if parts[1] ~= "" then
            local cwd = fs.currentdir()
            local prefix = split(cwd, pathSep)
            merge(prefix, parts)
            parts = prefix
        end
        return parts
    end

    local function getNonEmpty(parts)
        -- remove trailing slash, double slashes, dot
        local nonempty_parts = {}
        for index, part in pairs(parts) do
            if (index == 1 or part ~= "") and part ~= "." then
                table.insert(nonempty_parts, part)
            end
        end
        return nonempty_parts
    end

    local function doubleDot(parts)
        for index, part in pairs(parts) do
            if part == ".." then
                parts[index] = ""
                if parts[index-1] then
                    parts[index-1] = ""
                end
                parts = getNonEmpty(parts)
                parts = doubleDot(parts)
                break
            end
        end
        return parts
    end

    local function fixEmpty(path)
        if path == "" then
            path = pathSep
        end
        return path
    end

    parts = expandHomeDir(parts)
    parts = relativeToAbsolute(parts)
    parts = getNonEmpty(parts)
    parts = doubleDot(parts)
    local path = table.concat(parts, pathSep)
    return fixEmpty(path)
end

local function isStdInATty()
    return posix.isatty(posix.fileno(io.stdin)) == 1
end

-------------------------------------------------------------------------------

local function getStdinArgs()
    if isStdInATty() then
        return {}
    else
        local lines = {}
        while true do
            local line = io.read()
            if line == nil then
                break
            end
            table.insert(lines, line)
        end
        return lines
    end
end

local Selection = {}

function Selection:new()
    self.__index = self
    storage = "/dev/shm"
    if not isWritableDir(storage) then
        storage = "/tmp"
    end
    local path = storage..pathSep.."xfiles"
    return setmetatable({path=path}, self)
end

function Selection:readItems()
    local lines = {}
    local exists, f = pcall(io.input, self.path)
    if exists then
        for line in f:lines() do
            if line ~= "" then
                table.insert(lines, line)
            end
        end
        f:close()
    else
        self:clear()
    end
    return lines
end

function Selection:show()
    for _, item in pairs(self:readItems()) do
        print(item)
    end
end

function Selection:showPath()
    self:readItems()
    print(self.path)
end

function Selection:clear()
    local f = assert(io.open(self.path, "w"))
    f:write("")
    f:close()
end

function Selection:writeItems(items)
    local f = assert(io.open(self.path, "w"))
    f:write(table.concat(items, "\n"))
    f:close()
end

function Selection:add(items)
    local old_items = self:readItems()
    local unique_items = {}
    local ordered_items = {}

    local index = 1
    for _, item in pairs(old_items) do
        local item_norm = normalizePath(item)
        if not unique_items[item_norm] then
            unique_items[item_norm] = index
            index = index + 1
        end
    end

    for _, item in pairs(items) do
        local item_norm = normalizePath(item)
        if not unique_items[item_norm] then
            unique_items[item_norm] = index
            index = index + 1
        end
    end

    for item, index in pairs(unique_items) do
        ordered_items[index] = item
    end

    self:writeItems(ordered_items)
end

function Selection:remove(items)
    local old_items = self:readItems()
    for _, item in pairs(items) do
        local item_norm = normalizePath(item)
        for old_key, old_item in pairs(old_items) do
            if old_item == item_norm then
                old_items[old_key] = nil
                break
            end
        end
    end

    -- we want indices to be consecutive numbers
    local new_items = {}
    for _, item in pairs(old_items) do
        table.insert(new_items, item)
    end
    self:writeItems(new_items)
end


local selection = Selection:new()
local stdin_args = getStdinArgs()

arg[0] = nil --  script name
arg[-1] = nil -- interpreter

if #arg > 0 then
    local args = {table.unpack(arg)} -- clone
    local cmd = table.remove(args, 1)
    local cmd_args
    if #args > 0 then
        cmd_args = args
    else
        cmd_args = stdin_args
    end

    if cmd == '+' then
        selection:add(cmd_args)
        selection:show()
    elseif cmd == '-' then
        selection:remove(cmd_args)
        selection:show()
    elseif cmd == '++' then
        selection:showPath()
    elseif cmd == '--' then
        selection:clear()
    else
        selection:clear()
        selection:add(arg)
        selection:show()
    end
else
    if #stdin_args > 0 then
        selection:clear()
        selection:add(stdin_args)
    end
    selection:show()
end

