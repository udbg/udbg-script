
return function(args)
    local mod = args[1]
    package.loaded[mod] = nil
    require(mod)
end