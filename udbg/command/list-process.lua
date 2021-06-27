
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
    if os.name == 'windows' then
        local misc = require 'win.misc'
        function get_detail(item, path)
            if args.verify then
                item:insert(misc.verifyFile(path).info)
            end
            if args.info then
                local info = misc.getFileInfo(path)
                item:insert(info and info.FileDescription or '')
            end
        end
    else
        function get_detail(item, path) end
    end
    local data = table {}
    for p in enum_psinfo() do
        if #p.path > 0 then
            local item = table {p.pid, p.name, p.window, p.path, p.cmdline}
            get_detail(item, p.path)
            data:insert(item)
        end
    end
    out.tbl:set('data', data:reverse())
end

return mod