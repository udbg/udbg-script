
local MEM = require 'class'.bits {
    MEM_COMMIT = 0x1000,
    MEM_RESERVE = 0x2000,
    MEM_DECOMMIT = 0x4000,
    MEM_RELEASE = 0x8000,
    MEM_FREE = 0x10000,
}

return function(args)
    local a = eval_address(args[1])
    if a then
        log(' ', fmt_addr(a), get_symbol(a), get_symbol(a, 1))
        local m = virtual_query(a)
        if m then
            log(' ', 'alloc:', fmt_addr(m.alloc_base), 'base:', fmt_addr(m.base), 'size:', hex(m.size))
            log(' ', 'protect:', m.protect, 'type:', m.type, 'state:', MEM[m.State], 'private:', m & 'private', 'commit:', m & 'commit')
        end
    end
end