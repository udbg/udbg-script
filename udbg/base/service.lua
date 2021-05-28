
local Session = debug.getregistry().Session

function Session:__call(arg)
    if type(arg) == 'function' then
        local fun = arg
        local ups = {string.dump(fun)}
        for i = 2, 100 do
            local n, v = debug.getupvalue(fun, i)
            if not n then break end
            table.insert(ups, v)
        end
        self:notify('@call', ups)
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