
local client, args = ...
local path = os.path
_ENV.g_client = client

local root_dir = client:get 'root'
local script_dir = path.join(root_dir, 'script')
local config_dir = os.env 'UDBG_CONFIG' or path.join(root_dir, 'config')
client.config_dir = config_dir
local origin_paths = package.path
local lua_paths = {
    path.join(script_dir, '?.lua'),
    path.join(config_dir, '?.lua'),
    path.join(config_dir, '?.luac'),
}
package.path = table.concat(lua_paths, ';') .. ';' .. origin_paths

local service = require 'udbg.base.service'
_ENV.service = service; client.service = service

require 'udbg.lua'
local ui = require 'udbg.ui'
local event = require 'udbg.event'
event.error = ui.error
_ENV.ui, _ENV.uevent = ui, event
local readfile = readfile
local verbose = args.verbose and ui.log or function() end

verbose('[root_dir]', root_dir)
verbose('[args]', pretty ^ args)

local config = {
    data_dir = false,
    plugins = {},
    remote_map = {},
}
_ENV.g_config = config
setmetatable(config, {__index = _ENV})
local plugin_dirs = table {script_dir, config_dir}
do  -- load config/client.lua, init the plugin_dirs and package.path
    local config_path = path.join(config_dir, 'client.lua')
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
            ui.info('detected editor:', editor)
            config.edit_cmd = editor .. ' %1'
        else
            config.edit_cmd = 'start notepad %1'
        end
    end

    -- extend client
    function client:exit_ui(code)
        self:save_history(path.join(config.data_dir, '.cmd-history'))
        self:exit(code)
    end

    for _, plug in ipairs(config.plugins) do
        if plug.path then
            local dir = plug.path
            -- print('[plugin]', dir)
            assert(path.isdir(dir), 'plugin dir is not exists')
    
            plugin_dirs:insert(dir)
            table.insert(lua_paths, path.join(dir, '?.lua'))
            table.insert(lua_paths, path.join(dir, '?.luac'))
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

local function execute_lua(lua_path, data)
    data = data or readfile(lua_path)
    if data then
        -- TODO: bugfix notify
        g_session:request('lua_execute', {data, lua_path})
    else
        ui.warn('read', lua_path, 'failed')
    end
end

local watch_cache = table {}

local function execute_bin(lua_path, opt)
    if not path.isfile(lua_path) then
        local p = lua_path
        p = find_lua('udbg', 'bin', p) or
            find_lua('udbg', 'bin', p .. '.lua') or
            find_lua('udbg', 'bin', p .. '.luac')
        if not p then
            ui.warn(lua_path, 'not found')
        else
            lua_path = p
        end
    end

    local function edit_script()
        os.execute(config.edit_cmd:gsub('%%1', lua_path))
    end
    if lua_path and path.isfile(lua_path) then
        if opt.edit then
            edit_script()
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
        execute_lua(lua_path)
        return lua_path
    elseif opt.edit then
        -- try create this file
        if not path.isabs(lua_path) then
            local dir = path.isdir(config_dir) and config_dir or script_dir
            lua_path = path.withext(path.join(dir, 'bin', lua_path), 'lua')
        end
        if not path.exists(lua_path) then
            writefile(lua_path, '')
        end
        edit_script()
    end
end

local ucmd = require 'udbg.cmd'
do
    ucmd.prefix = 'udbg.client.cmd.'
    ucmd.no_outer = true

    function ucmd.load(modpath)
    end

local parser = [[
.exec                           execute a script
    <path> (optional string)    the script path

    -w, --watch                 watch the script
    -e, --edit                  edit this script
    --list-watch
]]
    ucmd.register('.exec', function(argv)
        if argv.path then
            execute_bin(argv.path, argv)
        elseif argv.list_watch then
            local k = next(watch_cache, #watch_cache)
            while k do
                local i = watch_cache[k]
                log(i, watch_cache[i], k)
                k = next(watch_cache, k)
            end
        end
    end
    , parser)

    ucmd.register('.show', function(argv)
        os.execute('explorer.exe /select,"' .. argv[1] .. '"')
    end)
end

do  -- rpc service function
    local searchpath = package.searchpath

    local on_ctrl_event = ui.on_ctrl_event
    service.on_ctrl_event = function(args)
        return on_ctrl_event(table.unpack(args))
    end

    function service.require(name)
        -- print('[require]', name)
        local lua_path
        if name:find('/', 1, true) then
            lua_path = find_lua(name)
        else
            lua_path = searchpath(name, package.path)
        end
        if lua_path then
            verbose('[require]', lua_path)
            return {lua_path, readfile(lua_path)}
        else
            verbose('[require failed]', name)
        end
    end

    function service.ui_info()
        return {'qt', root_dir, config.data_dir}
    end

    function service.fire_event(args)
        if type(args) == 'table' then
            event.fire(table.unpack(args))
        else
            event.fire(args)
        end
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
        client:exit_ui(code)
    end

    function service.execute_cmd(cmdline)
        cmdline = cmdline:trim()
        client:add_history(cmdline)
        log("[cmd] >> ", cmdline)
        if cmdline:sub(1, 1) == '.' then
            -- local argv = ucmd.parse(cmdline)
            -- local name = table.remove(argv, 1)
            -- local cmd = ucmd.find(name)
            -- if cmd then
            --     cmd.main(argv, ui.log)
            --     return
            -- end
            ucmd.dispatch(cmdline)
        end
        g_session:notify('execute_cmd', cmdline)
    end

    function service.collect_commands()
        local result = table {}
        for _, dir in ipairs(plugin_dirs) do
            for p in os.glob(path.join(dir, 'udbg', 'command', '*')) do
                local cmd = path.splitext(path.basename(p))
                result:insert(cmd)
            end
        end
        for cmd, _ in pairs(ucmd.cache) do
            result:insert(cmd)
        end
        return result
    end
end

do  -- start session
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
    _ENV.g_session = ss
    _ENV.g_shell_args = args

    function event.on.ui_inited(map)
        if not args.no_window then
            ui.main 'show'
        end
        require 'udbg.client.ui'
        g_session:notify('fire_event', {'ui-inited', map})
    end

    function event.on.cui_init()
        client:load_history(path.join(config.data_dir, '.cmd-history'))
    end

    function event.on.cui_close()
        client:exit_ui(0)
    end

    function event.on.target_success(info)
        client.target_alive = true
        ui.log('[target]', info)
        ui.add_recently(info.path)
        ui_notify(2, info)
    end

    function event.on.target_end()
        client.target_alive = false
        ui.g_status:set('text', 'Ended')
    end

    function event.on.session_close()
        _ENV.g_session = nil
        ui.error('session disconnected')
        ui.g_status.style = 'color:red;'
        ui.g_status:set('text', 'Disconnect')
    end

    function event.on.user_close()
        if g_session then
            g_session:notify('fire_event', 'user-close')
        else
            client:exit_ui(0)
        end
    end

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
    local cfg = {}
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

    -- execute udbg.plugin.init
    for _, dir in ipairs(plugin_dirs) do
        local lua_path = path.join(dir, 'udbg', 'plugin', 'init.lua')
        verbose('[plugin.init]', lua_path)
        execute_lua(lua_path)
    end

    -- execute lua for shell-args
    if args.execute then
        assert(
            execute_bin(args.execute, {watch = args.watch}),
            args.execute .. ' not found'
        )
    end

    event.on('execute_cmd', service.execute_cmd)

    function event.on.ui_pause(reason)
        print('[pause]', reason)
        service.execute_cmd('dis _pc -u 5 5')
    end

    -- monitor autorun
    function event.on.file_write(p)
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
                ui.info('[autorun]', 'target:', target)
            end

            if target == '.client' then
                assert(event.async_call(assert(load(data, p))))
            else
                execute_lua(p, data)
            end
        end
    end
    for _, dir in ipairs(plugin_dirs) do
        client:watch(path.join(dir, 'autorun'))
    end
end