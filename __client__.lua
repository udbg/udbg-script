
local client, args = ...
local path = os.path
_ENV.g_client = client
client.arguments = args

local CONFIG_NAME<const> = 'udbg-config.lua'
local root_dir = client:get 'root'
local script_dir = path.join(root_dir, 'script')
local origin_paths = package.path
local lua_paths = {
    path.join(script_dir, '?.lua'),
    path.join(script_dir, '?.luac'),
}
package.path = table.concat(lua_paths, ';') .. ';' .. origin_paths

local config_path = args.use_confdir or path.join(root_dir, CONFIG_NAME)
client.config_path = path.exists(config_path) and config_path or (function()
    -- find config directory upward
    local dir = path.dirname(os.getexe())
    while dir do
        local cfgpath = path.join(dir, CONFIG_NAME)
        if path.exists(cfgpath) then
            config_path = cfgpath
            return cfgpath
        end
        dir = path.dirname(dir)
    end
    path.copy(path.join(root_dir, 'default-config.lua'), config_path)
    return config_path
end)()

require 'udbg.lua'
local log = {} do
    _G.log = log
    setmetatable(log, log)

    local INFO<const> = 3
    local LOG<const> = 4
    local WARN<const> = 5
    local ERROR<const> = 6
    local concat = string.concat

    local logout = assert(client.log)
    local logcolor = assert(client.logcolor)

    function log.log(...)
        return logout(client, LOG, concat(...))
    end

    function log.warn(...)
        return logout(client, WARN, concat(...))
    end

    function log.info(...)
        return logout(client, INFO, concat(...))
    end

    function log.error(...)
        return logout(client, ERROR, concat(...))
    end

    local color = {
        [''] = 0, green = 1, blue = 2, gray = 3,
        yellow = 4, white = 5, black = 6, red = 7,
    }
    log.colormap = color
    function log.color(c, t, width)
        return logcolor(client, {color[c] or c, tostring(t), width})
    end

    function log.color_line(line)
        return logcolor(client, line)
    end

    function log:__call(...)
        return logout(client, LOG, concat(...))
    end

    __llua_error = log.error
end
local event = require 'udbg.event'
_ENV.uevent = event
local readfile = readfile
local verbose = args.verbose and log or function() end

verbose('[root_dir]', root_dir)
verbose('[args]', pretty ^ args)

local config = {
    precompile = true,
    precompile_strip = false,
    data_dir = false,
    plugins = {},
    remote_map = {},
    udbg_config = {},
}
client.config = setmetatable(config, {__index = _ENV})

local plugin_dirs = table {script_dir}
client.plugin_dirs = plugin_dirs
do  -- load config/client.lua, init the plugin_dirs and package.path
    local data = readfile(config_path)
    if data then
        verbose('[config path]', config_path)
        local fun = assert(load(data, config_path, 't', config))
        assert(event.async_call(fun))
        verbose('[client config]', pretty ^ config)
    end

    if not config.data_dir then
        config.data_dir = path.join(root_dir, 'data')
        if not path.isdir(config.data_dir) then
            os.mkdir(config.data_dir)
        end
    end
    assert(path.exists(config.data_dir))

    for _, plug in ipairs(config.plugins) do
        if type(plug) == 'string' then
            plug = {path = plug}
        end
        if plug.path then
            local dir = plug.path
            if path.isdir(dir) then
                plugin_dirs:insert(dir)
                table.insert(lua_paths, path.join(dir, '?.lua'))
                table.insert(lua_paths, path.join(dir, '?.luac'))
            else
                log.error(pretty % dir, 'is not directory')
            end
        end
    end
    package.path = table.concat(lua_paths, ';') .. ';' .. origin_paths
end

local function find_lua(...)
    for _, dir in ipairs(plugin_dirs) do
        local p = path.join(dir, ...)
        if path.isfile(p) then
            return p
        end
    end
end

local function searchpath(mod_path)
    mod_path = mod_path:gsub('%.', '/')
    return find_lua(mod_path .. '.lua') or find_lua(mod_path .. '.luac')
end

local function execute_lua(lua_path, data, mod_path)
    data = data or readfile(lua_path)
    if data then
        -- TODO: bugfix notify
        g_session:request('lua_execute', {data, lua_path, mod_path})
    else
        log.warn('read', lua_path, 'failed')
    end
end

function client:edit_script(lua_path)
    if not config.edit_cmd then
        local editor = nil
        for _, item in ipairs {'code', 'notepad++'} do
            local _, _, code = io.popen('where ' .. item):close()
            if code == 0 then
                editor = item
                break
            end
        end
        if editor then
            log.info('detected editor:', editor)
            config.edit_cmd = editor .. ' %1'
        else
            config.edit_cmd = 'start notepad %1'
        end
    end

    os.execute(config.edit_cmd:gsub('%%1', lua_path))
end

local watch_cache = table {}
client.watch_cache = watch_cache

function client:execute_bin(lua_path, opt)
    local mod_path
    if not path.isfile(lua_path) then
        mod_path = 'udbg.bin.' .. lua_path
        lua_path = searchpath(mod_path)
        if not lua_path then
            log.warn(lua_path, 'not found')
        end
    end

    if lua_path and path.isfile(lua_path) then
        if opt.edit then
            client:edit_script(lua_path)
            return lua_path
        end
        if opt.watch then
            local abspath = path.abspath(lua_path)
            local key = abspath
            if os.name == 'windows' then
                key = abspath:lower()
            end
            if not watch_cache[key] then
                watch_cache:insert(lua_path)
                watch_cache[key] = #watch_cache
                log('[watching]', lua_path, abspath)
                client:watch(lua_path)
            end
        end
        execute_lua(lua_path, nil, mod_path)
        return lua_path
    elseif opt.edit then
        -- try create this file
        if not path.isabs(lua_path) then
            local dir = path.isdir(config_path) and config_path or script_dir
            lua_path = path.withext(path.join(dir, 'bin', lua_path), 'lua')
        end
        if not path.exists(lua_path) then
            writefile(lua_path, '')
        end
        client:edit_script(lua_path)
    end
end

local service = require 'udbg.base.service'
package.loaded['udbg.base.service'] = nil
client:set('service', service)
-- rpc service function
client.service = service do
    function service.ui_info(device)
        verbose('[device]', device)
        local data_dir = path.join(config.data_dir, assert(device.id))
        os.mkdirs(data_dir)
        g_client.data_dir = data_dir
        log('[data_dir]', data_dir)

        local lsqlite3 = require 'lsqlite3'
        g_client.db = lsqlite3.open(path.join(data_dir, 'data.db'))
        g_client.db:exec [[
CREATE TABLE IF NOT EXISTS command_history (
    cmdline STRING   UNIQUE ON CONFLICT REPLACE,
    time    DATETIME DEFAULT ( (datetime('now', 'localtime') ) )
);

CREATE TABLE IF NOT EXISTS target_history (
    path STRING   UNIQUE ON CONFLICT REPLACE,
    time DATETIME DEFAULT ( (datetime('now', 'localtime') ) ),
    UNIQUE (
        path COLLATE NOCASE
    )
);
]]
        g_client:set('udbg_inited', true)
        return data_dir
    end

    local ui, qt
    -- extend client
    function client:finallyExit(code)
        ui.onClosed()
        self:exit(code)
    end

    function service.onUiInited()
        qt = require 'udbg.client.qt'
        ui = require 'udbg.client.ui'
        client.qt, client.ui = qt, ui
        if args.no_window then
            g_session:notify('call', "ui.cuiMode = true")
        else
            ui.main:show()
        end
        qt.gui(function()
            ui.init()

            event.fire('clientUiInited')
            g_session:notify('call', 'uevent.fire("uiInited")')
        end)
    end

    local handleCui = {
        ['F(7)'] = function() g_session:notify('call', "ui.continue('step')") end,
        ['F(8)'] = function() g_session:notify('call', "ui.continue('stepout')") end,
        ['F(9)'] = function() g_session:notify('call', "ui.continue('run', false)") end,
        ["CONTROL+Char('g')"] = function() g_session:notify('call', "ui.continue('run', false)") end,
        ['SHIFT+F(9)'] = function() g_session:notify('call', "ui.continue('run', true)") end,
        ['CONTROL+F(9)'] = function() g_session:notify('call', "ui.continue('stepout')") end,
        ["CONTROL+Char('d')"] = function() g_session:notify('call', "ui.try_break()") end,
        ["ALT+Char(';')"] = function()
            qt.gui(function()
                g_session:notify('call', "ui.cuiMode = false")
                ui.main:show()
                ui.main:setWindowState {'WindowActive'}
            end)
        end,
    }
    function service.onCuiKeyDown(key)
        local handler = handleCui[key]
        return handler and handler()
    end

    function service.onCuiClose()
        client:finallyExit(0)
    end

    function service.onSessionClose()
        ui.onTargetEnd()
        _ENV.g_session = nil
        log.error('session disconnected')
        ui.status:setStyleSheet 'color:red;'
        ui.status:setText 'Disconnect'
    end

    local ucmd = require 'udbg.cmd'; _G.ucmd = ucmd
    local stat
    function service.clientCommand(cmdline, ty)
        cmdline = cmdline:trim()
        if #cmdline == 0 then return end
        if not ty then
            if cmdline:starts_with("=") then
                ty = 'lua'
                cmdline = cmdline:sub(2)
            elseif cmdline:starts_with("*") then
                ty = 'eng'
                cmdline = cmdline:sub(2)
            else
                ty = 'udbg'
            end
        end
        if ty == 'lua' then
            log("[lua] >>", cmdline)
            g_session:notify("lua_eval", cmdline)
        elseif ty == 'eng' then
            g_session:notify("engine_command", cmdline)
        else
            log('[cmd] >>', cmdline)
            if cmdline:sub(1, 1) == '.' then
                ucmd.dispatch(cmdline)
            else
                g_session:notify('execute_cmd', cmdline)
            end
        end

        stat = stat or assert(g_client.db:prepare "REPLACE INTO command_history (cmdline) VALUES(?)", g_client.db:error_message())
        stat:bind_values(cmdline); stat:step(); stat:reset()

        g_client:add_history(cmdline)
        qt.gui(function()
            qt.metaCall(ui.command, 'addHistory', qt.QString(cmdline))
        end)
    end

    -- monitor autorun
    function service.onFileWrite(p)
        verbose('[file-write]', p)
        local _, ext = path.splitext(p)
        if ext:startswith 'lua' then
            local data = assert(readfile(p))
            local lineiter = data:gsplit '\n'
            local target = nil
            for i = 1, 10 do
                local line = lineiter()
                if not line then break end
                target = line:match '%s*%-%-+%s*udbg@(.-)%s+%-%-+'
                if target then break end
            end

            if target then
                client:info('[autorun]', 'target:', target)
            end

            if target == '.client' then
                assert(event.async_call(assert(load(data, p))))
            else
                execute_lua(p, data)
            end
        end
    end

    local arch = {x86 = 0, x86_64 = 1, arm = 2, arm64 = 3, aarch64 = 3}
    function service.onTargetSuccess(info)
        client.target_alive = true
        client:set('target_alive', true)
        log('[target]', info)
        qt.gui(function()
            ui.onTargetStart()
            ui.add_recently(info.path)
            qt.metaSet(ui.disasm, 'arch', arch[info.arch] or error 'invalid arch name')
        end)
    end

    function service.onTargetEnded()
        client.target_alive = false
        qt.gui(function()
            ui.onTargetEnd()
            client:set('target_alive', false)
            ui.status:setText 'Ended'
        end)
    end

    local function require_lua(name, precompile)
        -- print('[require]', name)
        local lua_path
        if name:find('/', 1, true) then
            lua_path = find_lua(name)
        else
            lua_path = searchpath(name)
        end
        if lua_path then
            verbose('[require]', lua_path)
            local res = readfile(lua_path)
            local size = #res
            if precompile and size > 2048 then
                res = assert(load(res, '@' .. lua_path))
                res = string.dump(res, config.precompile_strip)
                verbose('save the size:', (size - #res) / 1024)
            end
            return {lua_path, res}
        else
            verbose('[require failed]', name)
        end
    end
    function service.require(name)
        return require_lua(name, config.precompile)
    end

    function service.require_raw(name)
        return require_lua(name)
    end

    function service.filemeta(p)
        local m = path.meta(p)
        if m then
            return {
                len = m.len,
                is_dir = m.is_dir,
                modified = m.modified,
                created = m.created,
                readonly = m.readonly,
            }
        end
    end

    function service.exit(code)
        client:finallyExit(code)
    end
end

do  -- start session
    require 'udbg.luadebug'.add(INIT_COROUTINES)

    local remote = args.remote
    if remote then
        -- map the domain
        remote = remote:gsub('^[^:%s]+', function(domain)
            return config.remote_map[domain] or domain
        end)
        -- default port
        if not remote:find(':%d+$') then
            remote = remote .. ':2333'
        end
        args.real_remote = remote
    end
    local ss = client:start_session(remote)
    ---@type RpcSession
    _ENV.g_session = ss

    local function update_table_from_shell(t, item)
        local pos = item:find('=', 1, true)
        local k, v
        if pos then
            k = item:sub(1, pos-1)
            v = item:sub(pos+1)
            local ok, val = pcall(eval, v)
            if ok and val ~= nil then
                v = val
            end
        else
            k = item
            v = true
        end
        t[k] = v
    end

    -- set udbg.dbgopt
    ss:notify('update_global', {'udbg.dbgopt', args.opt})
    local cfg = config.udbg_config or {}
    for _, item in ipairs(args.config) do
        update_table_from_shell(cfg, item)
    end
    ss:notify('update_global', {'__config', cfg})

    -- execute client.init
    for _, dir in ipairs(plugin_dirs) do
        local lua_path = path.join(dir, 'udbg', 'client-init.lua')
        if path.exists(lua_path) then
            verbose('[client-init]', lua_path)
            assert(event.async_call(assert(loadfile(lua_path))))
        end
    end

    -- execute udbg.client.__init
    for _, dir in ipairs(plugin_dirs) do
        local lua_path = path.join(dir, 'udbg', 'client', '__init.lua')
        if path.exists(lua_path) then
            verbose('[udbg.client.__init]', lua_path)
            assert(event.async_call(assert(loadfile(lua_path))))
        end
    end

    -- execute udbg.__init
    for _, dir in ipairs(plugin_dirs) do
        local lua_path = path.join(dir, 'udbg', '__init.lua')
        if path.exists(lua_path) then
            verbose('[udbg.__init]', lua_path)
            execute_lua(lua_path)
        end
    end

    -- execute lua for shell-args
    for _, mod_path in ipairs(args.execute) do
        assert(
            client:execute_bin(mod_path, {watch = args.watch}),
            mod_path .. ' not found'
        )
    end

    for _, dir in ipairs(plugin_dirs) do
        dir = path.join(dir, 'autorun')
        if path.isdir(dir) then
            client:watch(dir)
        end
    end
end