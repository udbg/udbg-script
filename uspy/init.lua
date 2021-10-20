
require 'udbg.lua'

local uspy = {}

ui_session = g_udbg
require 'udbg.ui'
libffi = require 'libffi'
uspy.service = require 'uspy.service'

local dbg_, concat = dbg_, string.concat
function dbg(...) return dbg_(concat(...)) end

require 'udbg.alias'
ucmd = require 'udbg.cmd'
ucmd.prefix = 'uspy.command.'

function ucmd.load(modpath)
    -- try load from remote client
    local path, data = __loadremote(modpath)
    if data then
        return assert(load(data, path))()
    end
end

function inline_once(address, callback)
    inline_hook(address, function(...)
        callback(...)
        disable_hook(address)
    end)
end

_ENV.uspy = uspy
return uspy