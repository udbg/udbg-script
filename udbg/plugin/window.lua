
function uevent.on.ui_inited()
    ui.menu_plugin:add_action {title = '&Window List', on_trigger = ucmd.wrap ':list-window'}
end