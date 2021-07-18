
local mod = {}

mod.parser = [[
d                           Display Memory
    <address> (address)     内存地址
    <linecount> (default 8) 显示行数

    -w, --word
    -d, --dword
    -q, --qword
]]

function mod.main(args)
    local addr = args.address
    if not addr then return log('Invaild address') end

    local fmt = '%02X'
    local pack = ('I1'):rep(16)

    if args.word then
        fmt, pack = '%04X', ('I2'):rep(8)
    elseif args.dword then
        fmt, pack = '%08X', ('I4'):rep(4)
    elseif args.qword then
        fmt, pack = '%016X', ('I8'):rep(2)
    end

    for i = 1, args.linecount do
        local addr = addr + 16 * (i-1)
        local data = read_bytes(addr, 16)
        if not data then break end

        logc('gray', hex(addr) .. ' ')
        local t = {pack:unpack(data)}
        t[#t] = nil
        for j = 1, #t do t[j] = fmt:format(t[j]) end
        table.insert(t, '')
        logc('green', table.concat(t, ' '))
        local text = data:gsub('.', function(c)
            local byte = c:byte()
            return (byte < 32 or byte > 0x7f) and '.' or c
        end)
        logc('yellow', text .. '\n')
    end
end

return mod