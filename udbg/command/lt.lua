
return function(args, out)
    local windows = __llua_os == 'windows'
    if windows then
        out.title = {'tid', 'entry', 'teb', 'status', 'priority', 'suspend count', 'last error'}
        out.width = {6, 24, 18, 12, 12, 4, 10}
    end
    out.color = {'gray', 'yellow', 'green', 'red', 'yellow', 'blue'}
    for tid, t in pairs(thread_list()) do
        local entry = t.entry
        local sym = get_symbol(entry)
        entry = fmt_addr(entry)
        entry = sym and entry..'('..sym..')' or entry
        if windows then
            local suspend_count, last_eror = 0, 0
            suspend_count = t 'suspend' t 'resume'
            last_eror = t.error
            out(tostring(tid), entry, fmt_addr(t.teb), t.status, t.priority, suspend_count, hex(last_eror))
        else
            out(tostring(tid), t.priority, t.name, t.status)
        end
    end
end