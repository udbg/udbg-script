
local ui = require 'udbg.ui'

local ListenKey = {}
ListenKey.__index = ListenKey do
    local maps = {}
    local registed = {}
    -- https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
    local VK = {
        LBUTTON = 0x01,
        RBUTTON = 0x02,
        MBUTTON = 0x04,
        [';'] = 0xBB,
        ['+'] = 0xBB,
        [','] = 0xBC,
        ['-'] = 0xBD,
        ['.'] = 0xBE,
        F1 = 0x70,
        F2 = 0x71,
        F3 = 0x72,
        F4 = 0x73,
        F5 = 0x74,
        F6 = 0x75,
        F7 = 0x76,
        F8 = 0x77,
        F9 = 0x78,
        F10 = 0x79,
        F11 = 0x7A,
        F12 = 0x7B,
        F13 = 0x7C,
        F14 = 0x7D,
        F15 = 0x7E,
        F16 = 0x7F,
        F17 = 0x80,
        F18 = 0x81,
        F19 = 0x82,
        F20 = 0x83,
        F21 = 0x84,
        F22 = 0x85,
        F23 = 0x86,
        F24 = 0x87,
        SPACE = 0x20,
        PRIOR = 0x21,
        NEXT = 0x22,
        END = 0x23,
        HOME = 0x24,
        LEFT = 0x25,
        UP = 0x26,
        RIGHT = 0x27,
        DOWN = 0x28,
        SELECT = 0x29,
        PRINT = 0x2A,
        EXECUTE = 0x2B,
        SNAPSHOT = 0x2C,
        INSERT = 0x2D,
        DELETE = 0x2E,
        HELP = 0x2F,
        CONTROL = 0x11, CTRL = 0x11,
        MENU = 0x12, ALT = 0x12,
    }
    local LISTEN_KEY = 1004
    local CANCEL_LISTEN_KEY = 1005

    local function trans(key)
        key = key:upper()
        if #key == 1 then
            return string.byte(key)
        else
            return assert(VK[key])
        end
    end

    ui.ListenKey = ListenKey
    function ui.listen_key(obj)
        local keys = obj.keys
        assert(obj.callback)
        if type(keys) ~= 'table' then
            keys = {keys}
        end
        obj.name = table.concat(keys, '+')
        local keysid = {}
        for i, key in ipairs(keys) do
            key = trans(key)
            keys[i] = key
            keysid[i] = ('%x'):format(key)
        end
        keysid = table.concat(keysid)
        obj.keysid = keysid
        local old = registed[keysid]
        if old then
            ui.info('[ListenKey]', 'unregister', old.name)
            old:cancel()
        end

        local id = ui_request(LISTEN_KEY, keys)
        obj.id = id
        maps[id] = obj registed[keysid] = obj
        return setmetatable(obj, ListenKey)
    end

    function ListenKey:cancel()
        ui.notify(CANCEL_LISTEN_KEY, self.id)
        maps[self.id] = nil
        registed[self.keysid] = nil
    end

    local service = require 'udbg.service'
    function service.on_listen_key(id)
        local obj = maps[id]
        obj:callback()
    end
end

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
            ui.notify(DATA_PUSH, args)
        end
    end

    function Data:__newindex(key, val)
        if key == 'width' then
            ui.notify(DATA_WIDTH, {self[1], val})
        elseif key == 'filter' then
            ui.notify(DATA_FILTER, {self[1], val})
        elseif key == 'state' then
            ui.notify(DATA_STATE, {self[1], val})
        elseif key == 'color' then
            for i, v in ipairs(val) do
                val[i] = color[v] or 0
            end
            ui.notify(DATA_COLOR, {self[1], val})
        else
            rawset(self, key, val)
        end
    end

    function Data:__close()
        ui.notify(DATA_FLUSH, self[1])
    end

    function Data:__gc()
        ui.notify(DATA_CLOSE, self[1])
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