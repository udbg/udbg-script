
local msgpack = require 'msgpack'
local mpack, munpack = msgpack.pack, msgpack.unpack

local service = require 'udbg.base.service'
uspy.service = service

local c_reg = debug.getregistry()
c_reg[uspy.ref_rpc] = function(name, data)
    data = munpack(data)
    local fun = assert(service[name], 'service not found')
    return mpack(fun(data) or nil)
end

return service