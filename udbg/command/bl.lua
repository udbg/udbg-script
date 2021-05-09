
return function()
    for _, id in ipairs(get_bp_list()) do
        local address, t, c = get_bp(id, 'address', 'type', 'hitcount')
        logc('gray', fmt_addr(address) .. ' ' .. c .. ' ')
        logc('yellow', t .. ' ')
        log(get_symbol(address))
    end
end