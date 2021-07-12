
local serpent = require 'serpent'
local tablex = require 'pl.tablex'

local table, string = table, string

do -------- Extend table --------
    table.update = tablex.update
    table.union = tablex.union
    table.merge = tablex.merge
    table.imap = tablex.imap
    table.size = tablex.size
    table.filter = tablex.filter
    table.keys = tablex.keys
    table.find = tablex.find
    table.rfind = tablex.rfind
    table.find_if = tablex.find_if
    table.values = tablex.values
    table.copy = tablex.copy
    table.deepcopy = tablex.deepcopy
    table.compare = tablex.compare
    table.deepcompare = tablex.deepcompare
    table.foreach = tablex.foreach
    table.clear = tablex.clear
    table.foreach = tablex.foreach
    table.foreachi = tablex.foreachi
    table.makeset = tablex.makeset
    table.new = tablex.new
    table.set = tablex.set

    function table:swap_key_value(update)
        local r = {}
        for k, v in pairs(self) do r[v] = k end
        if update then self:update(r) end
        return r
    end

    function table:replace(k, v)
        local origin = self[k]
        self[k] = v
        return origin
    end

    function table:reverse()
        for i = 1, #self//2 do
            local r = #self + 1 - i
            self[r], self[i] = self[i], self[r]
        end
        return self
    end

    function table:search_item(k, v)
        if self[k] == v then return self end
        for _, t in pairs(self) do
            if type(t) == 'table' then
                local res = table.search_item(t, k, v)
                if res then return res end
            end
        end
    end

    function table:unpack_struct(names)
        local result = {}
        for i, name in ipairs(names) do
            result[name] = self[i]
        end
        return result
    end

    function table.binary_search(list, elem, comparator)
        comparator = comparator or function(a, b)
            if a == b then return 0 end
            if a < b then return -1 end
            if a > b then return 1 end
        end

        local floor = math.floor
        local min, max = 1, #list
        while min <= max do
            local mid = floor((max+min)/2)
            local r = comparator(list[mid], elem)
            if r == 0 then
                return mid
            elseif r > 0 then
                max = mid - 1
            else
                min = mid + 1
            end
        end

        if max > 0 then
            return nil, max
        end
    end

    setmetatable(table, {
        __call = function(self, t)
            return setmetatable(t, table)
        end
    })
    table.__index = table
end

do -------- Extend string --------
    require 'pl.text'.format_operator()

    local s = require'glue'.string
    string.trim = s.trim
    string.tohex = s.tohex
    string.fromhex = s.fromhex
    string.escape = s.escape
    string.gsplit = s.gsplit
    string.starts = s.starts

    local sx = require 'pl.stringx'
    string.startswith = sx.startswith
    string.endswith = sx.endswith
    string.split = sx.split
    string.count = sx.count
    string.lstrip = sx.lstrip
    string.rstrip = sx.rstrip
    string.lines = sx.lines
    string.shorten = sx.shorten
    string.expandtabs = sx.expandtabs
    string.join = sx.join
    string.replace = sx.replace
    string.splitlines = sx.splitlines
    string.splitv = sx.splitv
    string.title = sx.title

    local seropt = {indent = '  ', sortkeys = true, comment = false, nocode = true}
    local serialize = serpent.serialize
    local select = select
    function string.concat(...)
        if select('#', ...) == 1 and type(...) == 'string' then
            return ...
        end
        local t = {...}
        for i = 1,#t do
            if type(t[i]) ~= 'string' then
                t[i] = serialize(t[i], seropt)
            end
        end
        return table.concat(t, ' ')
    end

    function string.to_hex(str, ascii)
        local byte = string.byte
        local char = string.char
        local insert = table.insert
        local t = {}
        local s = {}
        for i = 1, #str do
            local c = byte(str, i)
            insert(t, '%02x' % c)
            if ascii then
                insert(s, c > 32 and c < 0xFF and char(c) or '.')
            end
        end
        return table.concat(t, ' '), ascii and table.concat(s, '') or nil
    end

    function string.unpack_struct(fmt, s, names, i)
        local values = {string.unpack(fmt, s, i)}
        return table.unpack_struct(values, names)
    end
end

do  -------- Pretty Format --------
    pretty = {} setmetatable(pretty, pretty)
    local seropt = {indent = '  ', sortkeys = true, comment = false, nocode = true}
    local lineopt = {sortkeys = true, comment = false, nocode = true}
    pretty.lineopt = lineopt
    local hexopt = {sortkeys = true, comment = false, nocode = true, numformat = '0x%X'}
    pretty.hexopt = hexopt
    local serpent_line = serpent.line

    function pretty:__call(val, opt)
        return serpent.block(val, opt or seropt)
    end

    function pretty:__mod(val)
        return serpent_line(val, lineopt)
    end

    function pretty:__pow(val)
        return serpent.block(val, seropt)
    end

    function pretty:__mul(val)
        return serpent.block(val, hexopt)
    end

    function hex_line(val)
        return serpent_line(val, hexopt)
    end
end

function loadfile(path, ...)
    return load(readfile(path), ...)
end

local type = type
function hex(n)
    if type(n) == 'number' then
        return '0x%x' % n
    else
        return n
    end
end

function HEX(n)
    if type(n) == 'number' then
        return '0%X' % n
    else
        return n
    end
end

---compile a lua expression to function
---@param expr string
---@param args string|string[]
---@param env table
---@return function|nil,string
function Eval(expr, args, env)
    if type(expr) == 'function' then return expr end

    local t = 'return ' .. expr
    if args then
        if type(args) == 'table' then
            t = 'local ' .. table.concat(args, ', ') .. ' = ... ' .. t
        else
            t = 'local ' .. args .. ' = ... ' .. t
        end
    end
    return load(t, '(eval)', 't', env or _ENV)
end

---evaluate a lua expression
---@param expr string
---@param opt string|string[]
---@return any
function eval(expr, opt)
    return assert(Eval(expr, opt))()
end

function int(n, base)
    if base == 16 then
        if type(n) == 'string' then
            n = n:gsub('^%s*0[Xx]', '')
        end
    end
    return tonumber(n, base)
end