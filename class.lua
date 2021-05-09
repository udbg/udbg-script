
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

-- TODO
-- Return a class object
--  class(...) -> instance
local function class(body)
    -- Attribute
    -- local attrs = body.__attr
    -- if attrs then
    --     assert(type(attrs) == 'table')
    --     for i = 1, #attrs do
    --         local attrname = attrs[i]
    --         attrs[i] = nil
    --         local attrfunc = rawget(body, attrname)
    --         assert(type(attrfunc) == 'function')
    --         attrs[attrname] = attrfunc
    --     end
    -- end
    local parent = body.parent
    local __index = body.__index
    local __newindex = body.__newindex

    -- Get
    function body:__index(key)
        -- print(key)
        -- local attrfunc = attrs and attrs[key]
        -- if attrfunc then return attrfunc(self) end
        return rawget(body, key) or (__index and __index(self, key))
               or (parent and parent.__index and parent.__index(self, key))
    end

    -- Set
    function body:__newindex(key, val)
        -- local attrfunc = attrs and attrs[key]
        -- if attrfunc then return attrfunc(self, val, 1) end
        if __newindex then
            return __newindex(self, key, val)
        else
            return rawset(self, key, val)
        end
    end
    return setmetatable(body, CLASS)
end

local lib = {}

function lib:__call(...) return class(...) end

lib.enum = class
{
    __init = function(self, t)
        for k, v in pairs(t) do
            self[k] = v self[v] = k
        end
    end
}


lib.bits = class
{
    __init = function(self, t)
        table.update(self, t)
        for k, v in pairs(t) do
            rawset(self, v, k)
        end
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