
---@type RpcSession
local Session = debug.getregistry().RpcSession

local notify = Session.notify
local request = Session.request

local function dump_closure(fun)
    -- luac, _ENV index, upvalues...
    local res = {string.dump(fun), 0}
    for i = 1, 256 do
        local n, v = debug.getupvalue(fun, i)
        if not n then break end
        if type(v) == 'table' and rawequal(v._G, _G) then
            res[2] = i
            v = false
        end
        table.insert(res, v)
    end
    return res
end

function Session:__call(key, arg, ...)
    if type(key) == 'function' then
        local foo = arg and request or notify
        return foo(self, '@call', dump_closure(key))
    end
    return notify(self, key, arg, ...)
end

function Session:__shl(fun)
    return request(self, '@call', dump_closure(fun))
end

---发起RPC调用，并且调用的结果是一个临时方法表
---
---request by rpc, and its response is a temp method table
---@param m integer|string|function 
---@return table @see `udbg.base.service` `function service:__shl(tempMethod, ...) end`
function Session:requestTempMethod(m, ...)
    local session = self
    return setmetatable(type(m) == 'function' and self << m or request(self, m, ...), {
        __gc = function(method)
            session:notify('@remove', method)
        end
    })
end