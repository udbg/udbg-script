
return function()
    for _, bp in ipairs(breakpoint_list()) do
        local address, t, c = bp.address, bp.type, bp.hitcount
        ui.logc('gray', fmt_addr(address) .. ' ' .. c .. ' ')
        ui.logc('yellow', t .. ' ')
        log(get_symbol(address))
    end
end