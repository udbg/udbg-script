
require 'udbg.lua'
require 'udbg.core'
require 'udbg.service'

class = require 'class'
ui = require 'udbg.ui'
__llua_error = log.error

ucmd = require 'udbg.cmd'
ucmd.prefix = 'udbg.command.'

uevent = require 'udbg.event'
uevent.error = ui.error

local lapp = require 'pl.lapp'
lapp.add_type('address', function(s)
    return assert(udbg.target:eval_address(s), 'invalid address expression')
end)

require 'udbg.util'

require 'udbg.luadebug'.add(INIT_COROUTINES)

---@type table<string, UDbgEngine>
udbg.engine = setmetatable({}, {
    __newindex = function(self, key, val)
        if type(key) == "string" then
            if not table.find(self, key) then
                table.insert(self, key)
            end
        end
        rawset(self, key, val)
    end,
})
udbg.set('service', require 'udbg.service')

local device = {os = os.name, arch = os.arch, udbg_version = udbg.version}
-- https://docs.rs/machine-uid/0.2.0/machine_uid/
if os.name == 'windows' then
    local reg = require 'win.reg'
    device.id = reg.HKEY_LOCAL_MACHINE:open [[SOFTWARE\Microsoft\Cryptography]]:get 'MachineGuid'
elseif os.name == 'android' then
    device.id = io.popen 'getprop ro.serialno':read 'a'
else
    local mid = readfile '/etc/machine-id' or readfile '/var/lib/dbus/machine-id'
    device.id = mid and mid:trim() or select(2, io.popen 'uname -a':read 'a':splitv '%s+')
end
__ui_data_dir = ui.session:request('ui_info', device)