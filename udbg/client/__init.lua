
ucmd.register('.exec', function(argv)
    if argv.path then
        g_client:execute_bin(argv.path, argv)
    elseif argv.list_watch then
        local watch_cache = g_client.watch_cache
        local k = next(watch_cache, #watch_cache)
        while k do
            local i = watch_cache[k]
            log(i, watch_cache[i], k)
            k = next(watch_cache, k)
        end
    end
end, [[
.exec                           execute a script
    <path> (optional string)    the script path

    -w, --watch                 watch the script
    -e, --edit                  edit this script
    --list-watch
]])

ucmd.register('.show', function(argv)
    os.execute('explorer.exe /select,"' .. argv[1] .. '"')
    -- client.qt.QDesktopServices.openUrl(client.qt.QUrl(argv[1]:gsub('\\', '/'), 'TolerantMode'))
end)

ucmd.register('.edit', function(argv)
    local path = assert(argv[1], 'no path')
    os.execute(g_client.config.edit_cmd:gsub('%%1', path))
end)

uevent.on.clientUiInited = function()
    local qt = require 'udbg.client.qt'
    local q = qt.helper
    local ui = g_client.ui
    local a = q.QAction {
        setText = 'PE View',
        ['triggered()'] = function()
            local base = qt.metaCall(ui.main:focusWidget(), 'getCell(QString)', qt.QString'Base')
            if base and not base:isEmpty() then
                g_client.service.clientCommand{'.pe-view '..base:toStdString()}
            end
        end,
    }
    ui.module:addAction(a)
    ui.memoryLayout:addAction(a)

    ui.module:addAction(q.QAction {
        setText = 'Download PDB',
        ['triggered()'] = function()
            local name = qt.metaCall(ui.module, 'getCell(int)', 0)
            if name and not name:isEmpty() then
                g_client.service.clientCommand{'.download-pdb '..name:toStdString()}
            end
        end,
    })
end