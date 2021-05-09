
return function(args)
    for path in os.glob(args[1]) do
        log(path)
    end
end