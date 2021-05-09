
local parser = [[
dump-memory                         转储内存，写到文件
    <path>     (string)             文件路径
    <base>     (optional string)    地址
    <size>     (optional number)    大小

    -m, --module (optional string)  转储指定模块
]]

return function(args)
    if args.module then
        local m = get_module(args.module)
        args.base = m.base
        args.size = m.size
    end
    writefile(args.path, read_bytes(EA(args.base), args.size))
end, parser