
local parser = [[
dis                          -- disassembly
    <address> (string)          address
    <count>   (default 10)      指令个数

    -u, --upward (default 0)    disasm upward
    --x86                       x86 32位模式
    --x64                       x86 64位模式
    --arm                       Arm Arm模式
    --thumb                     Arm Thumb模式
    --arm64                     Arm64模式
    --operand                   显示操作数
]]

local ui = require 'udbg.ui'

local function disup(cs, address, offset)
    local a = address - offset
    local result = {}
    while a < address do
        local d = cs:disasm(a)
        if not d or #d == 0 then break end
        table.insert(result, d)
        a = a + d.size
    end
    return result, a
end

local function discount(cs, address, count)
    local result = {}
    while #result < count do
        local d = cs:disasm(address)
        if not d or #d < 1 then break end
        table.insert(result, d)
        address = address + d.size
    end
    return result
end

local function output(fmt, arr, show_op)
    local pc = reg['_pc']
    for _, d in ipairs(arr) do
        local address = d.address
        local sym = get_symbol(address, 0)

        local addr = ('%14s '):format(fmt_addr(address))
        if address == pc then
            addr = addr:gsub('^..', '->')
            if not sym then sym = get_symbol(address) end
        end
        if sym then logc('blue', sym .. ':\n') end
        logc('gray', addr)
        logc('yellow', fmt:format(d.bytes:tohex()))
        log('', d.string)

        if show_op then
            for i = 0, 10 do
                local op, a1, a2, a3, a4, a5 = d(0, 'operand', i)
                if not op then break end
                log('   ', op, a1, a2, a3, a4, a5)
            end
        end
    end
end

return function(args)
    local address = parse_address(args.address)
    if not address or address == 0 then
        ui.error('invalid address')
        return
    end
    local m = get_module(address)
    local arch = m and m.arch or __llua_arch
    local a1, mode
    if args.x64 then arch = 'x86_64'
    elseif args.x86 then arch = 'x86'
    elseif args.arm then arch = 'arm'
    elseif args.thumb then a1, mode = 'arm', 'thumb'
    elseif args.arm64 then arch = 'arm64' end

    if arch == 'x86_64' then a1, mode = 'x86', '64'
    elseif arch == 'x86' then a1, mode = 'x86', '32'
    elseif arch == 'arm' then a1, mode = 'arm', 'arm'
    elseif arch == 'aarch64' or arch == 'arm64' then a1 = 'arm64' end

    local cs = capstone(a1, mode)
    local fmt = arch:find 'x86' and '%-16s' or '%-10s'

    local up = args.upward
    if up > 0 then
        local scale = a1:find 'arm' and 4 or 3
        local arr, ea
        for i = 0, up * scale do
            arr, ea = disup(cs, address, up + i)
            if #arr == up and ea == address then
                break
            end
        end
        output(fmt, arr)
    end

    output(fmt, discount(cs, address, args.count), args.operand)
    -- while count < args.count do
    --     local sym = get_symbol(address, 0)
    --     if sym then logc('blue', sym .. ':\n') end

    --     local d = cs:disasm(address)
    --     local bytes = d.bytes
    --     logc('gray', ('%14s '):format(fmt_addr(address)))
    --     logc('yellow', fmt:format(bytes:tohex()))
    --     log('', d.string)
    --     count = count + 1
    --     address = address + #bytes
    -- end
end, parser