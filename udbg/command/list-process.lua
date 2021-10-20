
local mod = {
    view_type = 'table',
    column = {
        {name = 'pid', width = 7},
        {name = 'name', width = 20},
        {name = 'window', width = 30},
        {name = 'path', width = 50},
        {name = 'cmdline', width = 100},
        {name = 'verify', width = 20},
        {name = 'desc', width = 50},
    },
}

mod.parser = [[
list-process
    --verify                 verify the image file
    --info                   show detailed info of image file
]]

local function getpid(view)
    return view:find 'table':line('.', 0)
end

function mod.on_view(vbox)
    local hbox = table.search_item(vbox, 'name', 'bottom_hbox')
    table.insert(hbox.childs, 2,  ui.button {
        title = '&Attach', on_click = function(self)
            udbg.start {target = getpid(self), attach = true}
            self._root 'close'
        end
    })
    table.insert(hbox.childs, 3, ui.button {
        title = '&Open', on_click = function(self)
            udbg.start {target = getpid(self), open = true}
        self._root 'close'
        end
    })
end

function mod.main(args, out)
    local get_detail
    local windows = {}
    if os.name == 'windows' then
        local win = require 'win.win'
        local lowname = table.makeset {'Default IME', 'MSCTFIME UI'}
        local misc
        function get_detail(item, path)
            if args.verify then
                misc = misc or require 'win.misc'
                item:insert(misc.verifyFile(path).info)
            else
                item:insert('')
            end
            if args.info then
                misc = misc or require 'win.misc'
                local info = misc.getFileInfo(path)
                item:insert(info and info.FileDescription or '')
            end
        end

        -- collect windows
        for w in win.enum_window() do
            local pid, tid = win.get_pid_tid(w)
            local name = win.get_text(w)
            if name then
                if not windows[pid] then
                    windows[pid] = table {}
                end
                local item = {handle = w, name = name}
                if lowname[name] then
                    windows[pid]:insert(item)
                else
                    windows[pid]:insert(1, item)
                end
            end
        end
    else
        function get_detail(item, path) end
    end
    local data = table {}
    for p in enum_psinfo() do
        if #p.path > 0 then
            local item = windows[p.pid]
            local windowname = item and item[1].name or ''
            item = table {p.pid, p.name, windowname, p.path, p.cmdline}
            get_detail(item, p.path)
            data:insert(item)
        end
    end
    out.tbl:set('data', data:reverse())
end

return mod