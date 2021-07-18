
require 'udbg.lua'
require 'udbg.core'
require 'udbg.service'

class = require 'class'
ui = require 'udbg.ui'
ucmd = require 'udbg.cmd'
ucmd.prefix = 'udbg.command.'
libffi = require 'libffi'
uevent = require 'udbg.event'
uevent.error = ui.error

require 'udbg.util'