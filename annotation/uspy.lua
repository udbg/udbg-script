
error 'this file should not be execute'

uspy = {}

---@class Session @RPC Session
local Session = {}

---notify
---@param method string
---@param args any
function Session:notify(method, args) end

---request
---@param method string
---@param args any
---@return any
function Session:request(method, args) end

---@type Session
g_udbg = {}

---@class HookArgs
---@field trampoline integer @trampoline address

---create a inline hook
---@param address integer
---@param callback function(HookArgs)
function inline_hook(address, callback) end

---create a table hook
---@param address integer
---@param callback function(HookArgs)
function table_hook(address, callback) end

---enable a hook
---@param address integer
function enable_hook(address) end

---disable a hook
---@param address integer
function disable_hook(address) end

---remove a hook
---@param address integer
function remove_hook(address) end

---write a .dmp file
---@param path string
---@param opt integer|"'mini'"|"'full'"
function write_dump(path, opt) end