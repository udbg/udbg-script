
return function(args)
    local address = args[1]
    if address == '*' then
        for _, id in ipairs(get_bp_list()) do
            del_bp(id)
        end
    else
        del_bp(address)
    end
end