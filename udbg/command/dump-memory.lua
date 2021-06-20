
local mod = {}

mod.parser = [[
dump-memory                         转储内存，写到文件
    <path>     (string)             文件路径
    <base>     (optional string)    地址
    <size>     (optional number)    大小

    -m, --module (optional string)  转储指定模块
]]

function mod.main(args)
    if args.module then
        local m = get_module(args.module)
        args.base = m.base
        args.size = m.size
    else
        args.base = EA(args.base)
    end
    log('[dump-memory]', hex(args.base), hex(args.size))
    ui.writefile(args.path, read_bytes(args.base, args.size))
    log('[dump-memory]', 'done')
end

return mod