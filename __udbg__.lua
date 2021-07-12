
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