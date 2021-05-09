
require 'udbg.plugin.ui'

if __llua_os == 'windows' then
    require 'udbg.plugin.window'
end

function uevent.on.target_success()
    if udbg.dbgopt.adaptor == 'windbg' then
        ui.main:find_child 'actionAutoUpdate'.value = false
    end
end