
local udbg = udbg
-- local pcall, type, require = pcall, type, require
function _ENV:__index(k)
    local val = udbg[k]
    -- if not val and type(k) == 'string' then
    --     k = k:gsub('_', '.')
    --     local ok, err = pcall(require, k)
    --     if ok then
    --         val = err
    --     end
    -- end
    rawset(self, k, val)
    return val
end
setmetatable(_ENV, _ENV)

require 'udbg.lua'
require 'udbg.core'
require 'udbg.service'

ui = require 'udbg.ui'
ucmd = require 'udbg.cmd'
ucmd.prefix = 'udbg.command.'
libffi = require 'libffi'
utask = require 'udbg.task'
uevent = require 'udbg.event'
uevent.error = ui.error

require 'udbg.util'
require 'udbg.alias'

local loadremote = __loadremote
function ucmd.load(modpath)
    -- try load from remote client
    local path, data = loadremote(modpath)
    if data then
        return assert(load(data, path))()
    end
end