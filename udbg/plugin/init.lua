
require 'udbg.plugin.ui'

if os.name == 'windows' then
    require 'udbg.plugin.window'
end

function uevent.on.target_success()
    if udbg.dbgopt.adaptor == 'windbg' then
        ui.main:find_child 'actionAutoUpdate':set('checked', false)
    end
end

-- load plugins
function uevent.on.ui_inited()
    local path = os.path
    local dir = path.dirname(os.getexe())
    for dll in os.glob(path.join(dir, 'plugin', '*.dll')) do
        local ok, err = pcall(udbg.load_plugin, dll)
        if ok then
            ui.info('[plugin]', dll)
        else
            ui.error('[plugin]', dll, err)
        end
    end
end