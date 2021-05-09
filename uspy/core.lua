
local msgpack = require 'msgpack'
local mpack, munpack = msgpack.pack, msgpack.unpack
local unpack = table.unpack
local c_reg = debug.getregistry()
local service = {}
__service = service
uspy.service = service

c_reg[uspy.ref_rpc] = function(name, data)
    data = munpack(data)
    if name == '' then
        local chunk = data[1]
        local fun = load(chunk, '', nil, _ENV)
        for i = 2, #data do
            debug.setupvalue(fun, i, data[i])
        end
        return mpack(fun() or nil)
    else
        local fun = service[name]
        -- log('[call]', name, data)
        return mpack(fun(unpack(data)) or nil)
    end
end

function inline_once(address, callback)
    inline_hook(address, function(...)
        callback(...)
        disable_hook(address)
    end)
end