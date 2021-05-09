
return function(args, out)
    out.color = {'gray', 'yellow', 'red'}
    out.sep = '\t'
    out.width = {8, 20, 30, 50, 100}
    for p in enum_psinfo() do
        out(tostring(p.pid), p.name, p.window, p.path, p.cmdline)
    end
end