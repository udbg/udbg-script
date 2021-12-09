
return function(argv)
    local name = assert(argv[1])
    local list = g_session << function()
        local res = table {}
        local symdir = assert(__config.symbol_cache)
        for m in name == '*' and udbg.target:enum_module() or require 'pl.seq'.list{udbg.target:get_module(name)} do
            local sig = m 'pdb_sig'
            if sig then
                local pdbname = m 'pdb_name' or m'pdb_path' and os.path.basename(m'pdb_path') or os.path.withext(m.name, 'pdb')
                res:insert {
                    base = m.base,
                    pdbname = pdbname, pdbsig = sig,
                    symdir = os.path.join(symdir, pdbname, sig),
                }
            else
                log.warn(m.name, 'have not pdbinfo')
            end
        end
        return res
    end

    thread.spawn(function()
        table.imap(function(t)
            local url = 'https://msdl.microsoft.com/download/symbols/' .. t.pdbname .. '/' .. t.pdbsig .. '/' .. t.pdbname
            local pdbpath = os.path.join(t.symdir, t.pdbname)
            if os.path.exists(pdbpath) then
                log.info('[skip]', pdbpath)
            else
                local fmt = 'Invoke-WebRequest %s -OutFile "%s"'
                local cmd = fmt:format(url, pdbpath)
                os.mkdirs(t.symdir)
                log('[cmd]', cmd)
                local status, code = os.execute('powershell -Command "' .. cmd .. '"')
                if status and code == "exit" then
                    log('success', cmd)
                    g_session(function()
                        get_module(t.base):load_symbol()
                    end)
                else
                    log.error(status, code)
                end
            end
        end, list)
        log.info('[download-pdb]', 'done')
    end)
end