
local parser = [[
e          Edit Memory
    <address> (string)
    <value>   (string)
    -b, --byte
    -w, --word
    -d, --dword
    -q, --qword
    -h, --hex
    -s, --string
]]

return function(args)
    local addr = EA(args.address)
    if not addr then return ui.error('Invaild address') end

    local write = write_bytes
    local value = args.value
    if args.string then
        value = args.value
    elseif args.hex then
        value = string.fromhex(value)
    else
        if args.byte then
            write = write_u8
        end
        if args.word then
            write = write_u16
        end
        if args.dword then
            write = write_u32
        end
        if args.qword then
            write = write_u64
        end
        value = tonumber(value)
    end
    log(write(addr, value))
end, parser