
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