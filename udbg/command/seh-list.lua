
local parser = [[
seh-list               read/write register
    <tid>   (number)   register
]]

return function(args, out)
    local th = open_thread(args.tid)
    local teb = assert(th.teb)
    -- TODO: wow64
    local p = read_ptr(teb)
    while p and p ~= 0 do
        local next, handler = read_ptr(p), read_ptr(p + udbg.target.psize)
        out(hex(handler), get_symbol(handler))
        p = next
    end
end, parser