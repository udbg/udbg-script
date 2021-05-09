
require 'udbg.lua'
require 'uspy.core'
require 'udbg.ui'

local dbg_, concat = dbg_, string.concat
function dbg(...) return dbg_(concat(...)) end

require 'udbg.alias'
ucmd = require 'udbg.cmd'
ucmd.prefix = 'uspy.command.'