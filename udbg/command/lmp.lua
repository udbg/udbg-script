
require 'udbg.alias'

local fmt_base = '%-18s'
local fmt_size = '%-10s'
local function print_region(region, out, address)
    local show = #region > 0
    if address then
        show = show and (address >= region.base and address < region.base + region.size)
    end
    if show then
        out(fmt_base:format(hex(region.base)), fmt_size:format(hex(region.size)), region.usage)
        -- out(fmt_base:format(hex(region.base)), fmt_size:format(hex(region.size)), region.usage)
        for _, i in ipairs(region) do
            out(fmt_base:format('  ' .. hex(i.base)), fmt_size:format(hex(i.size)), i.type, i.protect, i.usage)
        end
    end
end

return function(args, out)
    out.color = {'gray', 'gray', 'yellow', 'green'}
    local region = {base = 0, size = 0, usage = ''}

    local address = args[1]
    address = address and EA(address)
    for _, m in ipairs(get_memory_map()) do
        if m.alloc_base == region.base then
            region.size = region.size + m.size
            table.insert(region, m)
        else
            print_region(region, out, address)
            region = {m}
            region.base = m.alloc_base
            region.size = m.size
            region.usage = m.usage
        end
    end
    print_region(region, out, address)
end