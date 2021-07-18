
local ui = require 'udbg.ui'

ui.g_status, ui.actionStepIn, ui.actionStepOut, ui.actionRun,
ui.actionHandled, ui.actionRunToReturn, ui.actionAbout,
ui.menu_option, ui.menu_plugin = ui.main:find_child {
    'status', 'actionStepIn', 'actionStepOut', 'actionRun',
    'actionHandled', 'actionRunToReturn', 'actionAbout',
    'menuOption', 'menuPlugin',
}
ui.menu_option:add_action {
    title = '&Data Folder',
    icon = ':/ico/res/folder-horizontal-open.png',
    on_trigger = function()
        os.execute('start '..g_config.data_dir)
    end
}

local function user_reply(...)
    local args = {'ui.continue', ...}
    return function()
        g_session:notify('call_global', args)
    end
end
ui.actionStepOut.on_trigger = user_reply('stepout')
ui.actionStepIn.on_trigger = user_reply('step')
ui.actionRun.on_trigger = user_reply('run', false)
ui.actionHandled.on_trigger = user_reply('run', true)
ui.actionRunToReturn.on_trigger = user_reply('go_ret')

local about = ([[
Version: $version

Website: https://gitee.com/udbg/udbg
]])

ui.actionAbout.on_trigger = function()
    local version = g_session:request('get_global', 'udbg.version')
    ui.dialog {
        title = 'About', parent = true;

        ui.label {title = about:gsub('%$(%w+)', {version = version}), textFormat = 3},
    }:call 'exec'
end

ui.menuRecent = ui.main:find_child 'menuRecent'
local recently_path = os.path.join(g_config.data_dir, 'recently.lua')

local function on_recent(self)
    g_session:notify('call_global', {"udbg.start", {
        create = true,
        target = self.path,
        -- adaptor = ,
    }})
end

function ui.init_recently()
    local data = readfile(recently_path)
    local list = data and eval(data) or {}
    ui.menuRecent 'clear'
    for i, path in ipairs(list) do
        ui.menuRecent:add_action {
            title = '&' .. i .. '. ' .. path,
            path = path,
            on_trigger = on_recent
        }
    end
end

function ui.add_recently(path)
    local data = readfile(recently_path)
    local list = data and eval(data) or {}
    local i = table.find(list, path)
    if i then
        list[i], list[1] = list[1], list[i]
    else
        table.insert(list, 1, path)
    end
    writefile(recently_path, pretty ^ list)
    ui.init_recently()
end

ui.init_recently()