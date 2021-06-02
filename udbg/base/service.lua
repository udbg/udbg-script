
local Session = debug.getregistry().Session

local notify = Session.notify
local request = Session.request

function Session:__index(key)
    local val = Session[key]
    if not val then
        val = function(a1, ...)
            if select('#', ...) > 0 then
                notify(self, key, {a1, ...})
            else
                notify(self, key, a1)
            end
        end
    end
    return val
end

function Session:__call(key, arg, ...)
    if type(key) == 'function' then
        local fun = key
        local ups = {string.dump(fun)}
        for i = 2, 100 do
            local n, v = debug.getupvalue(fun, i)
            if not n then break end
            table.insert(ups, v)
        end
        local foo = arg and request or notify
        return foo(self, '@call', ups)
    end
    if select('#', ...) > 0 then
        return notify(self, key, {arg, ...})
    else
        return notify(self, key, arg)
    end
end

local service = {}
local unpack = table.unpack
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

service['@call'] = function(data)
    local chunk = data[1]
    local fun = load(chunk, '', nil, _ENV)
    for i = 2, #data do
        debug.setupvalue(fun, i, data[i])
    end
    local ok, r = xpcall(fun, debug.traceback)
    if ok then return r end
    require 'udbg.ui'.error(r)
    error(r)
end

return setmetatable(service, service)