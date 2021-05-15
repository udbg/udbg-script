
return function(args, out)
    for _ in enum_module() do end
    for m in enum_memory() do
        if m.executable and not get_module(m.base) then
            out(hex(m.base), hex(m.size), m.usage)
        end
    end
end