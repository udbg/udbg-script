
require 'udbg.base.session'

local service = {}
local unpack = table.unpack

-- register rpc handler with specified method
function service:__newindex(key, val)
    if type(val) == 'function' then
        local i = debug.getinfo(val, 'u')
        if i.nparams > 1 or i.isvararg then
            local origin = val
            val = function(args) return origin(unpack(args)) end
        end
    end
    rawset(self, key, val)
end

local lastmethod = 0x200000

---注册RPC处理器，返回自动生成的方法(号)
---
---register rpc handler, return generated temp method numbers
function service:__shl(tempMethod, ...)
    if type(tempMethod) == 'table' then
        local res = {}
        for k, v in pairs(tempMethod) do
            res[k] = self << v
        end
        return res
    end

    assert(type(tempMethod) == 'function')
    -- TODO: multithread
    local method
    for i = lastmethod, 0x800000 do
        lastmethod = i + 1
        if not rawget(self, i) then
            method = i
            break
        end
    end
    assert(method, 'no more method number')

    self[method] = tempMethod
    return method
end

-- remove generated temp methods
service['@remove'] = function(tempMethod)
    if type(tempMethod) == 'table' then
        for _, n in pairs(tempMethod) do
            if type(n) == 'number' then
                rawset(service, n, nil)
            end
        end
    elseif type(tempMethod) == 'number' then
        rawset(service, tempMethod, nil)
    end
end

function service:__call(key, val)
    rawset(self, key, nil)
    self[key] = val
end

---加载lua字节码并执行
---
---load luac and execute
service['@call'] = function(data)
    local chunk, ienv = data[1], data[2]
    local fun = load(chunk)
    local setupvalue = debug.setupvalue
    for i = 3, #data do
        setupvalue(fun, i-2, data[i])
    end
    -- index of _ENV
    if ienv > 0 then
        setupvalue(fun, ienv, _ENV)
    end
    return fun()
end

setmetatable(service, service)

local libffi = require 'libffi'
local fn = libffi.fn
local type = type
function service.fficall(proc, ...)
    if type(proc) == 'string' then
        proc = libffi.C[proc]
    else
        proc = fn(proc)
    end
    return proc and proc(...)
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

function service.call(script)
    if type(script) == 'table' then
        return assert(load(script[1]))(unpack(script, 2))
    else
        return assert(load(script))()
    end
end

return service