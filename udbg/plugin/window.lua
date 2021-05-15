
function uevent.on.ui_inited()
    ui.menu_plugin:add_action {title = '&Window List', on_trigger = ucmd.wrap ':list-window'}
    ui.view_handle:add_action {title = '&Close Handle', on_trigger = function(self)
        local h = ui.view_handle:line('.', 2)
        ucmd('close-handle ' .. h)
    end}
end