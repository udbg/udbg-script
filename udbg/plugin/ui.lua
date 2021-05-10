
local ui = require 'udbg.ui'
local json = require 'cjson'
local event = require 'udbg.event'

local thread = thread
local UI_PAUSE<const> = 10
local reply, reply_arg

local ui_pause = udbg.ui_pause

function ui.pause(reason)
    assert(__debug_thread.id == thread.id())

    -- suspend_target()
    ui_notify(UI_PAUSE, reason or 'Paused')
    local r, a = ui_pause()
    ui_notify(UI_PAUSE, '')
    if r then
        return r, a
    else
        return reply, reply_arg
    end
end

function ui.continue(a, b)
    reply, reply_arg = a, b
    udbg.ui_reply()
end

local function attach(line, open)
    if not line then return end
    local a = not open
    udbg.start {
        target = line[1],
        attach = a,
        open = open,
    }
end

local windows = __llua_os == 'windows'
local function update_thread_list(view_thread)
    local data = {}
    for tid, t in pairs(thread_list()) do
        local entry = t.entry
        local sym = get_symbol(entry)
        entry = fmt_addr(entry)
        entry = sym and entry..'('..sym..')' or entry
        if windows then
            local suspend_count = t 'suspend'
            local pc = t('reg', '_pc')
            sym = get_symbol(pc)
            pc = fmt_addr(pc)
            pc = sym and pc..'('..sym..')' or pc
            t 'resume'
            table.insert(data, {tid, entry, fmt_addr(t.teb), pc, t.status, t.priority, suspend_count, hex(t.error)})
        else
        end
    end
    table.sort(data, function(a, b) return a[1] < b[1] end)
    view_thread:set_data(data)
end

local update_thread
local to_update = {}
function ui.update_view(what)
    if update_thread then
        to_update[what] = true
        return
    end
    update_thread = thread.spawn(function()
        while udbg.target do
            if to_update.module then
                to_update.module = false
                local view_module = ui.view_module
                local data = table {}
                for m in enum_module() do
                    data:insert {m.name, fmt_addr(m.base), hex(m.size), fmt_addr(m.base + m.entry), m.arch, m.path, m'pdb_path'}
                end
                view_module:set_data(data)
            end
            if to_update.thread then
                to_update.thread = false
                update_thread_list(ui.view_thread)
            end

            thread.sleep(10)
        end
        update_thread = false
    end)
    return ui.update_view(what)
end

function ui.stop_target()
    if udbg.target then
        udbg.kill()
    end
    if udbg.target then
        ui.continue 'run'
    end
end

function ui.detach_target()
    if udbg.target then
        udbg.detach()
        ui.continue 'run'
    end
end

function ui.restart_target()
    ui.stop_target()
    thread.spawn(function()
        for _ = 1, 200 do
            if not udbg.target then break end
            thread.sleep(10)
        end
        if udbg.target then
            ui.error('[restart]', 'kill target failed')
        else
            udbg.start(udbg.dbgopt)
        end
    end)
end

function ui.show_attach()
    local function update_list(self)
        local view = self:find 'process-list'
        local data = {}
        for p in enum_psinfo() do
            table.insert(data, {p.pid, p.name, p.window, p.path, p.cmdline})
        end
        for i = 1, #data//2 do
            local r = #data + 1 - i
            data[r], data[i] = data[i], data[r]
        end
        view:set_data(data)
    end

    local dlg = ui.dialog {
        title = 'Attach', parent = true,
        minsize = {'half', 'half'},

        ui.table {
            name = 'process-list',
            column_title = {'Pid', 'Name', 'Caption', 'Path', 'Cmdline'},
            column_width = {7, 20, 30, 50, 100},

            on_dblclick = function(self, line)
                attach(line.data, self:find 'only-open'.value)
                self._root:close()
            end
        },
        ui.hbox {
            ui.checkbox {title = '&Open', name = 'only-open'}, 'stretch',
            ui.button {title = '&Refresh', on_click = update_list},
            ui.buttonbox {
                fixed = 'h', 'ok', 'cancel',
                on_accept = function(self)
                    attach(self:find'process-list':line '.', self:find 'only-open'.value)
                    self._root:close()
                end,
            },
        }
    }:raise()
    update_list(dlg)
    dlg:exec()
end

function event.on.ui_inited()
    ui.view_module, ui.view_pages, ui.view_thread,
    ui.menu_view, ui.menu_option, ui.menu_help,
    ui.menu_plugin, ui.g_status =
    table.unpack(ui.main:find_child {
        'module', 'memoryLayout', 'thread',
        'menuView', 'menuOption', 'menuHelp',
        'menuPlugin', 'status',
    })
    ui.view_module:add_action {
        title = '&Dump', on_trigger = function()
            local m = ui.view_module:line('.', 0)
            local path = ui.save_path {title = 'Save "'..m..'" To'}
            if path then
                ucmd {'dump-memory', '-m', m, path}
            end
        end
    }

    if windows then
        local view_thread = ui.view_thread
        view_thread.on_dblclick = function()
            local a = PA(view_thread:line('.', 1):match'%x+')
            ui.goto_cpu(a)
        end
        view_thread:set_title('TID', 'Entry', 'TEB', 'PC', 'Status', 'Priority', 'Suspend Count', 'Last Error')
        view_thread:set_width(6, 24, 18, 16, 12, 8, 4, 12)
        view_thread:add_action 'Goto Entry'.on_trigger = view_thread.on_dblclick
        view_thread:add_action 'Goto TEB'.on_trigger = function()
            local a = PA(view_thread:line('.', 2))
            ui.goto_mem(a)
        end
        view_thread:add_action 'Goto PC'.on_trigger = function()
            local a = PA(view_thread:line('.', 3):match'%x+')
            ui.goto_cpu(a)
        end
        view_thread:add_action '&Suspend'.on_trigger = function()
            local tid = tonumber(view_thread:line('.', 0))
            open_thread(tid) 'suspend'
        end
        view_thread:add_action '&Resume'.on_trigger = function()
            local tid = tonumber(view_thread:line('.', 0))
            open_thread(tid) 'resume'
        end
        ucmd.register('stack', function(args)
            local function echo(tid, th)
                if th then
                    th 'suspend'
                    local sp = hex(th('reg', '_sp'))
                    log('[stack] ' .. tid .. ' sp: ' .. sp)
                    ucmd('dp -r ' .. sp .. ' 30')
                    th 'resume'
                end
            end
            local tid = args[1]
            if tid == '*' then
                for tid, th in pairs(thread_list()) do
                    echo(tid, th)
                end
            else
                tid = tonumber(tid)
                echo(tid, open_thread(tid))
            end
        end)
        view_thread:add_action '&Stack'.on_trigger = function()
            ucmd('stack ' .. view_thread:line('.', 0))
        end
    end

    local actionAttach, actionDetach, actionPause, actionStop, actionRestart = table.unpack(
        ui.main:find_child {
            'actionAttach', 'actionDetach', 'actionPause', 'actionStop', 'actionRestart'
        }
    )
    actionAttach.on_trigger = ui.show_attach
    actionDetach.on_trigger = ui.detach_target
    actionStop.on_trigger = ui.stop_target
    actionPause.on_trigger = udbg.pause
    actionRestart.on_trigger = ui.restart_target

    if udbg.dbgopt.target then
        udbg.start(udbg.dbgopt)
    end
end

function event.on.ui_update(what)
    ui.update_view(what)
end

function event.on.user_close()
    local exit = true
    if udbg.target and not udbg.dbgopt.open then
        exit = ui.dialog {
            title = 'Target is running', parent = true;
            min_hint = false, max_hint = false;
            ui.label 'really exit?',
            ui.buttonbox {'yes', 'no'},
        }:exec() > 0
    end
    if exit then
        ui.save_target_data()
        ui.notify('exit', 0)
    end
end

function ui.load_target_data()
    local path = __data_dir..'/config.json'
    data = ui.readfile(path)
    if data then
        ui.info('[config]', 'load', path)
        table.update(udbg.config, json.decode(data))
    end
    if udbg.dbgopt.open then return end

    if __config.backup_breakpoint then
        local path = __data_dir..'/bplist.json'
        local data = ui.readfile(path)
        if data then
            ui.info('[bplist]', 'load', path)
            for m, list in pairs(json.decode(data)) do
                module_callback(m, function(m)
                    for _, item in ipairs(list) do
                        local a = item.symbol and parse_address(item.symbol) or m.base + item.rva
                        ui.info('[bp]', hex_line(item))
                        add_bp(a, {type = item.type, enable = item.enable})
                    end
                end)
            end
        end
    end
end

function ui.save_target_data(target)
    target = target or udbg.target
    if not target then return end

    local module_bp = {}
    for _, id in ipairs(get_bp_list()) do
        local info = get_bp(id, 'extra')
        if info then
            local list = module_bp[info.module]
            if not list then
                list = table {}
                module_bp[info.module] = list
            end
            info.enable = get_bp(id, 'enable')
            -- log(hex_line(item))
            list:insert(info)
        end
    end

    if __config.backup_breakpoint then
        local path = __data_dir..'/bplist.json'
        ui.info('[bplist]', 'save', path)
        ui.writefile(path, json.encode(module_bp))
    end

    local path = __data_dir..'/config.json'
    ui.info('[config]', 'save', path)
    ui.writefile(path, json.encode(udbg.config))
end

ucmd.register('cpu', function(args)
    ui.goto_cpu(args[1])
end)

ucmd.register('mem', function(args)
    ui.goto_mem(args[1])
end)

ucmd.register('page', function(args)
    ui.goto_page(args[1])
end)

function event.on.target_success()
    local target = udbg.target
    local image_base = target.image_base or 0
    local m
    if image_base == 0 then
        m = enum_module()()
        image_base = m and m.base or 0
    else
        m = get_module(image_base)
    end
    ui.goto_mem(image_base)
    if m then
        ui.goto_cpu(m.entry_point)
    end

    if udbg.dbgopt.open then
        ui.g_status.value = 'Opened'
    end
    ui.load_target_data()
end

function event.on.target_failure(err)
    ui.error('start target failed:', err)
end

function event.on.target_end(target)
    ui.save_target_data(target)
    ui.notify('fire_event', 'target-end')
end

return ui