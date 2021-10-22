
local service = require 'udbg.base.service'
local ui = require 'udbg.ui'
local event = require 'udbg.event'
local unpack, type = table.unpack, type

service.on_ctrl_event = ui.on_ctrl_event

function service.lua_execute(data, path, mod_path)
    local ok, r = event.async_call(assert(load(data, '@'..path, 'bt')))
    if ok then
        if #path > 0 then
            ui.info('[lua_execute]', path, 'success')
        end
        if mod_path then
            package.loaded[mod_path] = r or true
            if type(r) == 'table' then
                r = true
            end
        end
        return r
    end
    ui.error(r)
end

function service.lua_eval(expr)
    local fun, err = load('return ' .. expr)
    local eval = true
    if err then
        -- ui.warn(err)
        eval = false
        fun, err = load(expr)
    end
    if fun then
        local ok, result = xpcall(fun, debug.traceback)
        if not ok then
            return ui.error(result)
        end
        if eval then
            log('[lua_eval]', result)
        end
    end
end

function service.execute_cmd(cmdline)
    local ok, err = xpcall(ucmd, debug.traceback, cmdline, 'udbg.command.')
    if ok then return end

    if err:find 'command not found' then
        if not ucmd.call_global(cmdline) then
            service.lua_eval(cmdline)
        end
        return
    end
    -- if err:find 'command not found' and udbg.adaptor_name == 'spy' then
    --     spy_lua(function()
    --         local ui = require 'udbg.ui'
    --         local cmd = require 'udbg.cmd'
    --         local ok, err = xpcall(cmd.dispatch, debug.traceback, cmdline, 'uspy.command.')
    --         if not ok then ui.error(err) end
    --     end)
    -- else ui.error(err) end
    ui.error(err)
end

local busy = false
function service.engine_command(cmdline)
    if busy then
        ui.warn('*BUSY*')
        return
    end
    require'udbg.task'.spawn(function()
        busy = true
        log('[eng] >>', cmdline)
        udbg.do_cmd(cmdline)
        busy = false
    end, {name = 'engine-command'})
end

return service