
local win = require 'win.win'

local parser = [[
list-window
    <class>     (optional string)

    -p, --pid   (optional number)
    -a, --all
]]

return function(args, out)
    out.title = {'HWND:8', 'pid-tid:15', 'class:20', 'title:30'}
    local tbl = out.tbl
    if tbl then
        tbl:add_action {
            title = 'Close &Window',
            on_trigger = function(self)
                local hwnd = tonumber(tbl:line('.', 0))
                win.close(hwnd)
            end
        }
    end

    if not args.all and udbg.target then
        args.pid = udbg.target.pid
    else
        args.all = true
    end

    for w in win.enum_window() do
        local cls = win.get_class(w) or ''
        if cls:find(args.class or '') then
            local pid, tid = win.get_pid_tid(w)
            if args.pid and pid == args.pid or args.all then
                out(hex(w), pid..':'..tid, cls, win.get_text(w))
                if tbl and not win.is_visible(w) then
                    tbl:set_color(-1, 0, 'gray')
                end
            end
        end
    end
end, parser