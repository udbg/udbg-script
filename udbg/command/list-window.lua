
local mod = {
    column = {
        {name = 'HWND', width = 8},
        {name = 'pid-tid', width = 15},
        {name = 'class', width = 20},
        {name = 'title', width = 30},
    }
}

local win = require 'win.win'

mod.parser = [[
list-window
    <class>     (optional string)

    -p, --pid   (optional number)
    -a, --all
]]

local function on_close(obj)
    local hwnd = tonumber(obj:find'table':line('.', 0))
    win.close(hwnd)
end

local function on_show(obj)
    local hwnd = tonumber(obj:find'table':line('.', 0))
    win.show_window(hwnd, 'SHOW')
end

local function on_hide(obj)
    local hwnd = tonumber(obj:find'table':line('.', 0))
    win.show_window(hwnd, 'HIDE')
end

function mod.on_view(vbox)
    local hbox = table.search_item(vbox, 'name', 'bottom_hbox')
    hbox.childs:insert(2, ui.hbox {
        ui.button {title = '&Close', on_click = on_close},
        ui.button {title = '&Show', on_click = on_show},
        ui.button {title = '&Hide', on_click = on_hide},
    })
end

function mod.main(args, out)
    local tbl = out.tbl

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
end

return mod