
require 'udbg.lua'
require 'udbg.ui'
require 'uspy.service'

local dbg_, concat = dbg_, string.concat
function dbg(...) return dbg_(concat(...)) end

require 'udbg.alias'
ucmd = require 'udbg.cmd'
ucmd.prefix = 'uspy.command.'

function inline_once(address, callback)
    inline_hook(address, function(...)
        callback(...)
        disable_hook(address)
    end)
end