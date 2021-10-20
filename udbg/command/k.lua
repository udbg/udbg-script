
local mod = {}

mod.column = {
    {name = 'Frame'},
    {name = 'Return'},
    {name = 'From'},
    {name = 'StackSize'},
}

mod.parser = [[
k                            -- show stack
    <tid> (optional number)
    -p, --params                show params
    --max (default 100)         max frames
]]
local serpent = require 'serpent'
local function pointer(p, ret)
    local t, info = pointer_info(p, ret)
    local color = 'green'
    if t == 'wstring' then
        info = 'L' .. serpent.line(info)
    elseif t == 'cstring' then
        info = serpent.line(info)
    elseif t == 'symbol' then
        color = 'blue'
    elseif t == 'return' then
        color = 'red'
    else info = nil end
    return info, t
end

function mod.main(args, out)
    local pc = reg._pc
    local cx
    if args.tid then
        local t = open_thread(args.tid)
        t:suspend()
        cx = t.wow64 and t.context32 or t.context
        t:resume()
        ui.info('[stack]~'..args.tid)
    end
    local count = 0
    for f in stack_walk(udbg.target, cx) do
        count = count + 1
        if count > args.max then
            ui.warn('overrange', 'max', args.max)
            break
        end
        local ret = f.ret
        local frame_size = f.frame - f.stack
        local insn = detect_return(ret)
        out(hex(f.frame), hex(ret), get_symbol(ret) or '', {fg = 'red', text = insn and insn.string or ''})
        if args.params then
            local params = {f'params'}
            if pc == f.pc then
                params = {reg[1], reg[2], reg[3], reg[4]}
            end
            for i, v in ipairs(params) do
                out(tostring(i), hex(v), pointer(v))
            end
        end
    end
end

return mod