
return function(args)
    local s = io.popen(table.concat(args, ' '))
    for l in s:lines() do log(l) end
end