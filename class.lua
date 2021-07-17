
local rawget, rawset = rawget, rawset
local setmetatable = debug.setmetatable

-- Metatable of class object
local CLASS = {}

function CLASS:__call(...)
    local this = setmetatable({}, self)
    local __newindex = self.__newindex
    self.__newindex = nil

    local construct = rawget(self, '__init')
    local result = this
    if construct then
        result = construct(this, ...)
        if result == nil then result = this end
    end

    -- 如果result为false，则返回false
    self.__newindex = __newindex
    return result and setmetatable(result, self)
end

local metaMethod = {
    '__call', '__close', '__gc',
    '__add', '__sub', '__mul', '__div', '__idiv', '__unm', '__pow', '__mod',
    '__and', '__or', '__not',
    '__band', '__bor', '__bnot', '__bxor', '__shl', '__shr',
    '__len', '__lt', '__le', '__eq', '__len',
}
local function class(body)
    local parent = body.__parent
    local __index = body.__index
    local __newindex = body.__newindex

    if parent then
        for _, name in ipairs(metaMethod) do
            if parent[name] and not body[name] then
                body[name] = parent[name]
            end
        end
    end

    local parentIndex = parent and parent.__index
    function body:__index(key)
        local val = rawget(body, key)
        if val == nil and __index then
            val = __index(self, key)
        end
        if val == nil and parentIndex then
            val = parentIndex(self, key)
        end
        return val
    end

    local get = body.__get
    if type(get) == 'table' then
        local index = body.__index
        function body:__index(key)
            local getter = get[key]
            if getter then return getter(self, key) end
            return index(self, key)
        end
    end

    local set = body.__set
    if type(set) == 'table' then
        function body:__newindex(key, val)
            local setter = set[key]
            if setter then return setter(self, val) end
            if __newindex then
                return __newindex(self, key, val)
            end
            return rawset(self, key, val)
        end
    end

    return setmetatable(body, CLASS)
end

local lib = {}

function lib:__call(...) return class(...) end

lib.enum = class {
    __init = function(self, t)
        for k, v in pairs(t) do
            self[k] = v self[v] = k
        end
    end
}

lib.bits = class {
    __init = function(self, t)
        table.update(self, t)
        table.swap_key_value(self, true)
    end,
    -- Combine All Bit String of a Number
    __index = function(self, key)
        -- print('bits', 'key', key)
        if math.type(key) == 'integer' then
            local t = {}
            for k, v in pairs(self) do
                if type(v) == 'number' and key & v > 0 then
                    table.insert(t, k)
                end
            end
            return table.concat(t, ' | ')
        else
            return rawget(self, key)
        end
    end,
    -- Get String of a bit
    __bor = function(self, bit)
        return rawget(self, bit)
    end,
}

return setmetatable(lib, lib)