
local mod = {is_task = true}

mod.parser = [[
sym                          -- show module symbols
    <name> (string)             module name
    <filter> (default '*')      symbol filter

    -u, --uname                 show undecorated name
    --len                       show length of the symbol
]]

local showlen = false
local showuname = false

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

function mod.main(args, out, task)
    showlen = args.len
    showuname = args.uname

    if args.showlen then
        out.color = {'gray', 'gray', ''}
    else
        out.color = {'gray', ''}
    end
    for m in enum_module() do
        if m.name:wildmatch(args.name) then
            show(m, args.filter, task, out)
        end
        if task.abort then break end
    end
    out.progress = 100
end

return mod