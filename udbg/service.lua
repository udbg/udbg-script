
local service = require 'udbg.base.service'
local types = require 'udbg.types'
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

do  -- Struct Monitor View
    local function get_value(ty, address)
        if ty.name and ty.name:match 'char%s*%*$' then
            return read_string(read_ptr(address))
        end
        if ty.pointer_level then return hex(read_ptr(address)) end
        if ty.struct then return "" end
        local val = types.read_type(ty, address)
        if not val then return '?' end
        if ty.pointer_level then return hex(val) end
        if is_integer(val) then
            return val .. ', ' .. hex(val)
        end
        return val
    end

    function service.get_value(args)
        local ts, addr = unpack(args)
        local address = parse_address(addr)
        if not address then return '<address error>' end
        local ty = types.def(ts)
        return get_value(ty, address)
    end
    
    function service.get_childs_value(args)
        local ts, addr = unpack(args)
        local address = parse_address(addr)
        local ty = types.def(ts)
        local field_list = ty.field_list
        if ty.pointer_level == 1 then
            address = address and read_ptr(address)
        end
        if not address then return '<address error>' end
        if not field_list then return '<no fields>' end
        local result = {}
        for _, f in ipairs(field_list) do
            local a = address + f.offset
            table.insert(result, {a, get_value(f.type, a)})
        end
        return result
    end
    
    -- get type info from string
    -- @param ts: type string
    function service.get_type(ts)
        local ty = types.def(ts)
        local has_child = ty.struct
        return {has_child = has_child, size = ty.size}
    end
    
    -- get field list of the type: ts
    -- @param ts: parent type string
    function service.get_field_list(ts)
        local ty = types.def(ts)
        local field_list = ty.field_list
        if ty.pointer_level == 1 then
            field_list = ty.field_list
        end
        local result = {}
        if field_list then
            for i, f in ipairs(field_list) do
                local ty = f.type
                local has_child = ty.struct and (ty.pointer_level or 0) < 2
                result[i] = {
                    name = f.name, type = ty.name, size = ty.size,
                    offset = f.offset, has_child = has_child,
                }
            end
        end
        return result
    end
end

return service