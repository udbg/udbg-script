
if os.name == 'windows' then
    package.cpath = os.path.dirname(os.getexe())..[[\?54.dll;]]..package.cpath

    function uevent.on.uiInited()
        ui.menu_plugin:add_action {title = '&Window List', on_trigger = ucmd.wrap ':list-window'}
        ui.menu_plugin:add_action {title = 'Scan &Patch', on_trigger = ucmd.wrap ':scan-patch *'}

        ui.view_module:add_action {title = 'Scan &Patch', on_trigger = function()
            -- local name = ui.view_module:line('.', 0)
            local base = ui.view_module:line('.', 1)
            ucmd(':scan-patch ' .. base)
        end}

        ui.view_handle:add_action {title = '&Close Handle', on_trigger = function(self)
            local h = ui.view_handle:line('.', 2)
            ucmd('close-handle ' .. h)
        end}
    end
end

function uevent.on.targetSuccess()
    if udbg.dbgopt.adaptor == 'windbg' then
        ui.main:find_child 'actionAutoUpdate':set('checked', false)
    end
end

-- load plugins
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