
local mod = {}

mod.parser = [[
dp                                   -- display pointer
    <start> (address default '_sp')     start address
    <count...> (optional number)        count of each level item to show

    -r, --ret                   only return
    -s, --symbol                only symbol
    -i, --info                  has info
]]

function mod.main(args, out)
    local start = args.start
    local psize = udbg.target and udbg.target.psize or __llua_psize
    local counts = args.count
    -- log(count)
    if #counts == 0 then counts[1] = 10 end

    local get_info, collect
    function get_info(p, depth)
        local color, info, t = pointer_color_info(p, true)
        local r = {color = color, info = info, type = t}
        collect(r, depth+1, p)
        return r
    end

    function collect(result, depth, start)
        local count = counts[depth] if not count then return end
        local i, c = 0, 0
        while c < count do
            local offset = psize * i
            local a = start + offset
            local p = read_ptr(a)
            if not p then break end

            local sub = get_info(p, depth)
            sub.address = a sub.ptr = p sub.offset = offset
            local info, t = sub.info, sub.type

            if args.info and not info and #sub == 0 then goto next end
            if args.ret and t ~= 'return' then goto continue end
            if args.symbol and t ~= 'symbol' and t ~= 'return' then goto continue end
            -- log(color, info, t)
            table.insert(result, sub)

            ::next:: c = c + 1
            ::continue:: i = i + 1
        end
    end
    local result = {}
    collect(result, 1, start)

    local display
    if out.tbl then
        function display(r, depth)
            for _, i in ipairs(r) do
                local color, info, t = i.color, i.info, i.type
                local extra
                if info then
                    if t == 'return' then
                        extra = info[1].string
                        info = get_symbol(i.ptr)
                    end
                end
                out(string.rep('  ', depth-1), '+0x%04x ' % i.offset, hex(i.address), hex(i.ptr), info, extra)
                if #i > 0 then
                    display(i, depth+1)
                end
            end
        end
    else
        function display(r, depth)
            for _, i in ipairs(r) do
                local color, info, t = i.color, i.info, i.type
                ui.logc('green', string.rep('  ', depth-1))
                ui.logc('gray', '+0x%04x ' % i.offset)
                ui.logc('gray', fmt_addr(i.address) .. ' ')
                ui.logc('yellow', fmt_size(i.ptr) .. ' ')
                if info then
                    if t == 'return' then
                        info = info[1].string
                        ui.logc('green', get_symbol(i.ptr))
                        local m = get_module(i.ptr)
                        ui.logc('gray', m and m:find_function(i.ptr) and ' *' or ' ')
                    end
                    ui.logc(color, info)
                end
                log ''
                if #i > 0 then
                    display(i, depth+1)
                end
            end
        end
    end
    display(result, 1)
end

return mod