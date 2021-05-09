
local msgpack = require 'msgpack'
local type = type
local mpack, munpack = msgpack.pack, msgpack.unpack

local mod = {}
setmetatable(mod, mod)

local spy_lua = udbg.spy_lua
local function call_spy(fun, nowait)
    local ups = {string.dump(fun)}
    for i = 2, 100 do
        local n, v = debug.getupvalue(fun, i)
        if not n then break end
        table.insert(ups, v)
    end
    local result, err = spy_lua('', mpack(ups), nowait)
    if err then
        ui.error(err)
    elseif #result > 0 then
        return munpack(result)
    end
end
mod.call_spy = call_spy

function mod:__call(arg, ...)
    if type(arg) == 'function' then
        return call_spy(arg, true)
    end
    return munpack(spy_lua(arg, mpack{...}))
end

function mod:__index(key)
    if type(key) == 'function' then
        return call_spy(key, false)
    end
    local result = function(...)
        return spy_lua(key, mpack{...})
    end
    rawset(self, key, result)
    return result
end

return mod