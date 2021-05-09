
local parser = [[
sym                          -- show module symbols
    <name> (string)             module name
    <filter> (optional string)  symbol filter

    -u, --uname                 show undecorated name
    --len                       show length of the symbol
]]

local showlen = false
local showuname = false
local abort = false
local function show(m, filter, task, out)
    local iter = m:enum_symbol(filter)
    local base = m.base
    for s in iter do
        if task.abort then break end
        local name = s.name
        local uname
        if showuname then
            uname = s.uname
        end
        name = m.name .. '!' .. name
        if showlen then
            out(fmt_addr(base + s.offset), hex(s.len), name, uname)
        else
            out(fmt_addr(base + s.offset), name, uname)
        end
    end
end

return function(args, out)
    showlen = args.len
    showuname = args.uname
    require 'udbg.task'.spawn(function(task)
        if args.showlen then
            out.color = {'gray', 'gray', ''}
        else
            out.color = {'gray', ''}
        end
        if args.name == '*' then
            for m in enum_module() do
                show(m, args.filter, task, out)
                if abort then break end
            end
        else
            local m = assert(get_module(args.name), 'invalid module')
            show(m, args.filter, task, out)
        end
    end)
end, parser