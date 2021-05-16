
local service = require 'udbg.base.service'
local types = require 'udbg.types'
local ui = require 'udbg.ui'
local event = require 'udbg.event'
local unpack, type = table.unpack, type

local creg = debug.getregistry()
creg[udbg.ref_rpc] = function(method, data)
    local callback = service[method]
    if callback then
        return callback(data)
    end
    error 'invalid lua method'
end

service.on_listen_key = ui.on_listen_key
service.on_ctrl_event = ui.on_ctrl_event

function service.fire_event(args)
    if type(args) == 'table' then
        event.fire(table.unpack(args))
    else
        event.fire(args)
    end
end

function service.lua_execute(data, path)
    local ok, r = event.async_call(assert(load(data, path)))
    if ok then
        if #path > 0 then
            ui.info('[lua_execute]', path, 'success')
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
    thread.spawn(function()
        busy = true
        log('[eng] >>', cmdline)
        udbg.do_cmd(cmdline)
        busy = false
    end)
end

function service.call(script)
    if type(script) == 'table' then
        return assert(load(script[1]))(unpack(script, 2))
    else
        return assert(load(script))()
    end
end

local function parse_expr(global)
    local t = _ENV
    for k in global:gsplit('.', 1, true) do
        if not t then break end
        t = t[k]
    end
    return t
end

function service.call_global(args)
    if type(args) == 'table' then
        local fun = parse_expr(args[1])
        return fun(unpack(args, 2))
    else
        local fun = parse_expr(args)
        return fun()
    end
end

function service.memory_operand(address)
    local insn = disasm(address)
    if insn then
        for i = 0, 5 do
            local ot, val = insn(0, 'operand', i)
            if ot == 'mem' then return val end
        end
    end
end

function service.modify_memory(a, ts, value)
    local address = parse_address(a)
    if not address then
        return ui.error('Invalid Address', a)
    end
    local ok, err = pcall(function()
        local ty = types.def(ts)
        ty[address] = value
    end)
    if not ok then ui.error(err) end
end

function service.set_global(name, val)
    -- log('[set_global]', args)
    _ENV[name] = val
end

function service.get_global(var)
    -- log('[get_global]', var, _ENV[var])
    local val = _ENV[var]
    if val == nil then
        val = parse_expr(var)
    end
    return val
end

function service.update_global(var, t)
    local val = parse_expr(var)
    if type(val) ~= 'table' then
        ui.error(var, 'is', 'not', 'a', 'table')
        return
    end
    if type(t) == 'string' then
        t = eval('{' .. t .. '}')
    end
    if type(t) == 'table' then
        for k, v in pairs(t) do val[k] = v end
    end
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