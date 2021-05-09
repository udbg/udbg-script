
local libffi = require 'libffi'
local k32 = libffi.load 'kernel32'
local u32 = libffi.load 'user32'
local ps = libffi.load 'psapi'
local nt = libffi.load 'ntdll'

local api = {}

function api:__index(name)
    local fun = k32[name] or u32[name] or ps[name] or nt[name]
    if fun then
        rawset(self, name, fun)
        return fun
    end
end

return setmetatable(api, api)