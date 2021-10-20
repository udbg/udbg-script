
return function(args)
    local address = args[1]
    if address == '*' then
        for _, bp in ipairs(breakpoint_list()) do
            bp:remove()
        end
    else
        local bp = get_breakpoint(address)
        if bp then
            bp:remove()
        end
    end
end