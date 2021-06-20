
local ui = require 'udbg.ui'

local Data = {} ui.Data = Data
do      -- data
    local DATA_NEW = 1010
    local DATA_PUSH = 1011
    local DATA_COLOR = 1012
    local DATA_WIDTH = 1013
    local DATA_FLUSH = 1014
    local DATA_CLOSE = 1015
    local DATA_FILTER = 1016
    local DATA_STATE = 1017

    function Data.new(name)
        local key = ui_request(DATA_NEW, name or '')
        return setmetatable({key}, Data)
    end

    local find = string.find
    local color = ui.color
    function Data:__call(...)
        local args = {self[1], ...}
        local filter = self.lua_filter
        local found = false
        if filter then
            for i = 2, #args do
                if type(args[i]) == 'string' then
                    found = find(args[i], filter)
                end
                if found then break end
            end
        else
            found = true
        end
        if found then
            ui_notify(DATA_PUSH, args)
        end
    end

    function Data:__newindex(key, val)
        if key == 'width' then
            ui_notify(DATA_WIDTH, {self[1], val})
        elseif key == 'filter' then
            ui_notify(DATA_FILTER, {self[1], val})
        elseif key == 'state' then
            ui_notify(DATA_STATE, {self[1], val})
        elseif key == 'color' then
            for i, v in ipairs(val) do
                val[i] = color[v] or 0
            end
            ui_notify(DATA_COLOR, {self[1], val})
        else
            rawset(self, key, val)
        end
    end

    function Data:__close()
        ui_notify(DATA_FLUSH, self[1])
    end

    function Data:__gc()
        ui_notify(DATA_CLOSE, self[1])
    end
end

do      -- counter table
    function ui.count_table(opt)
        local name = opt.name or ''
        local showhex = opt.hex
        local symbol = opt.symbol

        local t = ui.table {
            columns = {
                {name = 'count', width = 8},
                {name = 'value', width = 30},
                {name = 'symbol', width = 100},
            },
        }
        ui.dialog {title = 'Count: ' .. name, t} 'show' 'raise'
        local count_cache = {}
        local index_cache = {}
        local index = 0

        return function(value)
            local count = count_cache[value] or 0
            if count == 0 then
                index_cache[value] = index; index = index + 1
                symbol = symbol and is_integer(value) and get_symbol(value) or ''
                t:append {count, showhex and hex(value) or value, symbol}
            end
            count = count + 1
            count_cache[value] = count

            t:set_line(index_cache[value], 0, count)
        end
    end
end

return ui