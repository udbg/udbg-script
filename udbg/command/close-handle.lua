
local DUPLICATE_CLOSE_SOURCE<const> = 1

return function(args, out)
    local handle = assert(tonumber(args[1], 16))
    local pshandle = assert(udbg 'handle')
    local b = require 'win.api'.DuplicateHandle(pshandle, handle, 0, 0, 0, 0, DUPLICATE_CLOSE_SOURCE)
    if b == 0 then
        ui.error(udbg.get_last_error())
    else
        out('[close-handle]', 'success')
    end
end