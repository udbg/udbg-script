
local ui = require 'udbg.ui'
local lapp = require 'pl.lapp'

function lapp.quit(msg, no_usage)
    -- if not no_usage then log(_ENV.usage) end
    ui.error(msg) error('')
end

local cmd = {
    use_cache = true,
    no_outer = false,
    prefix = 'udbg.command.'
}
setmetatable(cmd, cmd)

local function split_cmdline(cmdline)
    local args = {}
    local pos = 1
    while pos <= #cmdline do
        -- print(pos)
        -- Ignore space-white
        pos = cmdline:find('%S', pos)
        if not pos then break end
        local c = cmdline:sub(pos, pos)
        local arg = ''
        -- print(pos, c)
        -- Quoted item or word item
        if c == "'" or c == '"' then
            local pat = '[^' .. c ..  ']+'
            while true do
                local endpos = cmdline:find(c, pos+1, true)
                if not endpos then break end
                local s = cmdline:sub(pos, endpos)
                pos = endpos + 1
                if s:sub(-2, -2) == '\\' then
                    arg = arg .. s:gsub('..$', c)
                else
                    arg = arg .. s
                    break
                end
            end
        else
            arg = cmdline:match('%S+', pos)
            pos = pos + #arg
        end
        table.insert(args, arg)
    end
    return args
end
cmd.split_cmdline = split_cmdline

local ipairs = ipairs
local function trim_quote(args)
    for i, arg in ipairs(args) do
        if arg:find '^[\'"]' then
            arg = arg:sub(2, -2)
            args[i] = arg
        end
    end
    return args
end
cmd.trim_quote = trim_quote

function cmd.parse(cmdline, parse_number)
    local args = split_cmdline(cmdline)
    local filter, outype, name
    if args[1] and args[1]:match '^:' then
        args[1] = args[1]:sub(2)
        outype = 'table'
        name = table.concat(args, ' ')
    end

    local r = {}
    for i, arg in ipairs(args) do
        if arg:match '^>' then
            outype = 'file'
            name = arg:sub(2)
        elseif arg:match '^%|' then
            filter = arg:sub(2)
        else
            table.insert(r, arg)
        end
    end
    trim_quote(r)
    return r, filter, outype, name
end

function cmd.load(modpath, reload)
    local result = package.loaded[modpath]
    if reload then result = nil end

    if result then return result end
    for _, searcher in ipairs(package.searchers) do
        local loader = searcher(modpath)
        if type(loader) == 'function' then
            local ok, res = xpcall(loader, debug.traceback)
            if ok then
                package.loaded[modpath] = res
                return res
            end
            ui.error(res)
        end
    end
end

local Filter = {} do
    function Filter:__call(...)
        local filter = rawget(self, 'filter')
        local color = rawget(self, 'color')
        local format = rawget(self, 'format')

        if filter then
            local str = string.concat(...)
            if not str:find(filter) then return end
        end

        if color then
            local args = {}
            args.sep = rawget(self, 'sep')
            for i, v in ipairs{...} do
                local n = i * 2
                args[n-1] = color[i] or ''
                local fmt = format and format[i]
                args[n] = fmt and fmt:format(v) or v
            end
            return ui.clog(args)
        end
        if format then
            local args = {...}
            for i, v in ipairs(args) do
                local fmt = format and format[i]
                args[i] = fmt and fmt:format(v) or v
            end
            return ui.log(table.unpack(args))
        end
        ui.log(...)
    end
    -- function out:log(...) self(ui.log, ...) end
    -- function out:info(...) self(ui.info, ...) end
    -- function out:warn(...) self(ui.warn, ...) end
    Filter.__index = Filter
end

function cmd.call_global(cmdline)
    local argv, filter = cmd.parse(cmdline, true)
    local name = table.remove(argv, 1)  -- command name
    local fun = _ENV[name]
    if type(fun) == 'function' then
        local out = setmetatable({filter=filter}, Filter)
        local r = fun(table.unpack(argv))
        if type(r) == 'function' then
            while true do
                local item = {r()}
                if #item == 0 then break end
                out(hex_line(item))
            end
        elseif type(r) == 'table' then
            if #r > 0 then
                for _, item in ipairs(r) do
                    out(hex_line(item))
                end
            else
                out(r)
            end
        else
            if type(r) == 'number' then
                out(hex(r))
            else
                out(tostring(r))
            end
        end
        return true
    end
end

---@class Column
---@field name string
---@field title string
---@field width integer

---@class Command
---@field main function
---@field name string
---@field parser string?
---@field view_type string?
---@field registered boolean?
---@field menu CtrlOpt[] @right-click menu
---@field column Column[]|string[]

-- find specific command
---@type table<string, Command>
local cache = {} cmd.cache = cache

---find command by name
---@param name string
---@param prefix? string
---@return Command?
function cmd.find(name, prefix)
    -- try load from cache(cmd.register(...))
    local result = cache[name]
    -- try load from file
    if not result then
        prefix = prefix or cmd.prefix
        local modpath = prefix .. name
        result = cmd.load(modpath, not cmd.use_cache)
        if type(result) == 'function' then
            result = {main = result, name = name}
        end
    end

    return result
end

local function table_outer(name, command)
    local tbl = ui.table {name = 'table', columns = command.column}
    local outer = {icol = 0, line = 0, tbl = tbl}
    local progress = ui.progress {name = 'progress', value = 0}
    local vbox = ui.vbox {
        tbl, ui.hbox {
            name = 'bottom_hbox',
            ui.button {
                title = '&Refresh', on_click = function()
                    tbl 'clear'
                    outer.docmd()
                end
            },
            progress,
        }
    }

    if command.on_view then
        command.on_view(vbox)
    end

    ui.dialog {title = name, size = {0.5, 0.5}; vbox} 'show' 'raise'
    tbl:add_action {
        title = 'Goto &CPU',
        on_trigger = function()
            ui.goto_cpu(tbl:line('.', '.'):trim())
        end
    }
    tbl:add_action {
        title = 'Goto M&emory',
        on_trigger = function()
            ui.goto_mem(tbl:line('.', '.'):trim())
        end
    }
    tbl:add_action {
        title = 'Goto P&age',
        on_trigger = function()
            ui.goto_page(tbl:line('.', '.'):trim())
        end
    }
    if command.menu then
        for _, item in ipairs(command.menu) do
            tbl:add_action(item)
            item.table = tbl
            item.outer = outer
        end
    end

    outer.__index = outer
    outer.__call = function(self, ...)
        if self.icol > 0 then
            local args = {...}
            for i = 1, #args do
                tbl:set_line(-1, self.icol + i - 1, args[i])
            end
            self.icol = 0
        else
            tbl:append({...})
        end
        self.line = self.line + 1
    end
    outer.__newindex = function(self, key, val)
        if key == 'width' then
            tbl:set('columnWidths', val)
        elseif key == 'title' then
            tbl:set('columns', val)
        elseif key == 'progress' then
            progress.value = val
        else
            rawset(self, key, val)
        end
    end
    function outer:color(fg, cell)
        if self.line == 0 then
            tbl:append {''}
        end
        local icol = self.icol
        tbl:set_line(-1, icol, cell)
        tbl:set_color(-1, icol, fg)
        self.icol = icol + 1
    end
    return setmetatable(outer, outer)
end

---dispatch command
---@param cmdline string|table
---@param prefix? string
function cmd.dispatch(cmdline, prefix)
    local argv, filter, outype, outname
    if type(cmdline) == 'table' then
        argv = cmdline
        filter = cmdline.filter
        outype = cmdline.output
        outname = cmdline.name
    else
        argv, filter, outype, outname = cmd.parse(cmdline)
    end
    local name = table.remove(argv, 1)  -- command name
    local command = cmd.find(name, prefix)
    assert(command, 'command not found')

    if command.view_type then
        outype = command.view_type
    end

    -- parse cmdline
    local err, suc, args, task
    local main, parser = command.main, command.parser
    if type(parser) == 'table' then
        task = parser.task
        parser = parser.parser
    end

    if type(parser) == 'string' then
        suc, args = pcall(lapp, parser, argv)
        if not suc then err = args end
    elseif not parser then
        -- 没有语法，传递解析好的参数
        args = argv
    else
        error('commnad ' .. name .. ': invalid parser type: ' .. type(parser))
    end

    if err then
        log(parser)
    elseif args then
        local outer
        if not cmd.no_outer then
            if outype == 'table' then
                outer = table_outer(outname, command)
            else
                local filename = ''
                if outype == 'file' then
                    filename = outname
                end
                outer = require'udbg.uix'.Data.new(filename)
            end
        end
        -- outer.filter = filter
        if outer then outer.lua_filter = filter end
        local function docmd() main(args, outer) end
        if task then
            function docmd()
                require 'udbg.task'.spawn(function()
                    main(args, outer)
                end, {name = cmdline})
            end
        end
        if outer then outer.docmd = docmd end
        docmd()
    end
end

function cmd.register(name, a1, a2)
    local main, parser
    if a2 then main, parser = a1, a2
    else main = a1 end

    assert(type(main) == 'function')
    cache[name] = {parser = parser, main = main, registered = true, name = name}
end

function cmd.wrap(cmdline)
    return function()
        return cmd.dispatch(cmdline)
    end
end

function cmd:__call(...)
    return cmd.dispatch(...)
end

return cmd