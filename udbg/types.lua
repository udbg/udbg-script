
local rawget, rawset = rawget, rawset
local math_type = math.type
local assert = assert
local Type = {} Type.__index = Type
local CVal = {}
local pointer_size = __llua_psize

local types = {}
do  -- basic types
    local function add_type(self, name, ty)
        if not ty.name then
            rawset(ty, 'name', name)
        end
        rawset(self, name, ty)
    end
    setmetatable(types, {__newindex = add_type})

    types.void = setmetatable({proto = 'void', size = 0}, Type)
    types.i8 = setmetatable({proto = 'i8', size = 1, signed = true}, Type)
    types.u8 = setmetatable({proto = 'u8', size = 1, signed = false}, Type)
    types.i16 = setmetatable({proto = 'i16', size = 2, signed = true}, Type)
    types.u16 = setmetatable({proto = 'u16', size = 2, signed = false}, Type)
    types.i32 = setmetatable({proto = 'i32', size = 4, signed = true}, Type)
    types.u32 = setmetatable({proto = 'u32', size = 4, signed = false}, Type)
    types.i64 = setmetatable({proto = 'i64', size = 8, signed = true}, Type)
    types.u64 = setmetatable({proto = 'u64', size = 8, signed = false}, Type)
    types.f32 = setmetatable({proto = 'f32', size = 4, float = true}, Type)
    types.f64 = setmetatable({proto = 'f64', size = 8, float = true}, Type)
    types.isize = setmetatable({proto = 'isize', size = pointer_size, signed = true}, Type)
    types.usize = setmetatable({proto = 'usize', size = pointer_size, signed = false}, Type)

    types.byte = types.u8
    types.bool = types.u8
    types.char = types.i8
    types.short = types.i16
    types.wchar = types.i16
    types.ushort = types.u16
    types.int = types.i32
    types.uint = types.u32
    types.long = types.i64
    types.ulong = types.u64
    types.size_t = types.usize
    types.float = types.f32
    types.double = types.f64
end

local function read_ty(ty, address)
    local read_value = ty.read_value
    if read_value then
        return read_value(address)
    elseif ty.pointer_level then
        return read_ptr(address)
    else
        return read_type(address, ty.name)
    end
end

do  -- Type
    local function Type___index(self, key)
        local field_list = rawget(self, 'field_list')
        return field_list and field_list[key]
    end

    function Type:__call(address, field)
        if field then
            field = Type___index(self, field)
            if not field then return end
            local ty = field.type
            address = address + field.offset
            return ty.struct and address or read_ty(ty, address)
        else
            return CVal.new(address + 0, self)
        end
    end

    function Type:__newindex(address, value)
        if math_type(address) ~= 'integer' then
            return rawset(self, address, value)
        end
        local write_value = self.write_value
        if write_value then
            return write_value(address, value)
        elseif self.pointer_level then
            return write_ptr(address, tonumber(value))
        else
            return write_type(address, self.name, tonumber(value))
        end
    end

    -- function Type:__len()
    --     return rawget(self, 'size')
    -- end

    -- function Type:__tostring()
    --     return self.name or types[self]
    -- end

    function Type:__band(field)
        field = Type___index(self, field)
        return field and field.offset
    end
end

do  -- CVal
    local const F_ADDR = -1
    local const F_TYPE = -2
    local const FIELDLIST = -3
    local const PTR_LEVEL = -4

    function CVal.new(address, ty, pointer_level)
        assert(type(address) == 'number')
        pointer_level = pointer_level or ty.pointer_level or 0
        return setmetatable({
            [F_ADDR] = address, [F_TYPE] = ty,
            [FIELDLIST] = ty.field_list or false,
            [PTR_LEVEL] = pointer_level,
        }, CVal)
    end

    local struct_error = 'not a struct'
    function CVal:__index(key)
        local address = self[F_ADDR]
        local pl = self[PTR_LEVEL]
        local ty = self[F_TYPE]
        if pl > 0 then
            -- assert(type(key) == 'number')
            return CVal.new(read_ptr(address + key * pointer_size), ty, pl - 1)
        end

        local field = assert(self[FIELDLIST], struct_error)[key]
        if not field then return end

        address = address + field.offset
        ty = field.type
        pl = ty.pointer_level or 0

        if pl > 0 then
            if ty.struct then pl = pl - 1 end
            return CVal.new(read_ptr(address), ty, pl)
        end
        if ty.struct then
            return CVal.new(address, ty)
        end
        -- if ty.array_count then
        -- end
        return read_type(address, ty.name)
    end

    function CVal:__newindex(key)
        -- TODO:
    end

    function CVal:__add(offset)
        return self[F_ADDR] + offset
    end

    function CVal:__band(field)
        field = assert(self[FIELDLIST], struct_error)[field]
        return field and self[F_ADDR] + field.offset
    end

    -- with read_value
    function CVal:__mul(field)
        field = assert(self[FIELDLIST], struct_error)[field]
        return field and read_ty(self[F_TYPE], self[F_ADDR] + field.offset)
    end
end

local function align(offset, size)
    if size == 0 then return offset end
    local n = offset % size
    if n ~= 0 then
        offset = offset + size - n
    end
    return offset
end

local lib = {types = types, Type = Type, read_type = read_ty}
local ty_cache_p1 = {}

function lib.def(declare, nn)
    local name, stars, narr = declare:match '%s*([%w_]+)%s*(%**)%s*([%[%]%d]*)'
    local pointer_level = #stars
    local array_count = #narr > 0 and tonumber(narr:sub(2, -2)) or nil
    local ty = assert(types[name], 'type ' .. name .. ' not exists')
    if pointer_level == 0 and not array_count then return ty end

    local result
    if pointer_level == 1 then
        result = ty_cache_p1[ty]
    end
    if not result then
        local t = table.copy(ty)
        t.name = declare
        t.pointer_level = pointer_level
        t.array_count = array_count
        t.cellsize = pointer_level > 0 and pointer_size or t.size
        t.size = (array_count or 1) * t.cellsize
        result = setmetatable(t, Type)
        if pointer_level == 1 then
            ty_cache_p1[ty] = result
        end
    end
    if nn then types[nn] = result end
    return result
end

function lib.struct(field_list)
    local this = setmetatable({
        alignment = field_list.alignment,
        size = 0, max_field_size = 0,
        field_list = {}, struct = true,
    }, Type)
    for _, field in ipairs(field_list) do
        lib.add_field(this, field)
    end
    return this
end

function lib.add_field(self, field)
    local field_list = assert(getmetatable(self) == Type and self.field_list, 'not a struct')

    local ty = field[1] or field.type
    if type(ty) == 'string' then ty = lib.def(ty) end
    local name = field[2] or field.name
    local offset = field.offset

    local meta = getmetatable(ty)
    assert(meta == Type and ty.size > 0 and type(name) == 'string' and not field_list[name])
    -- calculate the offset
    local mfs = ty.max_field_size or ty.cellsize or ty.size
    if mfs > self.max_field_size then
        self.max_field_size = mfs
    end
    local alignment = self.alignment or mfs
    if not offset then
        offset = align(self.size, alignment)
    end
    -- insert this field
    local pos = 0
    for i = #field_list, 1, -1 do
        local f = field_list[i]
        if offset >= f.offset then pos = i break end
    end
    field = {name = name, type = ty, offset = offset}
    field_list[name] = field table.insert(field_list, pos + 1, field)
    -- update struct size
    local last = field_list[#field_list]
    self.size = align(last.offset + last.type.size, alignment)
end

return lib