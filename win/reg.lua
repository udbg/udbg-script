
local libffi = require 'libffi'
local adv = libffi.load 'advapi32.dll'
local malloc = libffi.malloc
local err = require 'win.err'

local RegKey = {}
RegKey.__index = RegKey

function RegKey:open(subkey)
    local buf = malloc(8)
    if adv.RegOpenKeyA(self.hkey, subkey, buf) == 0 then
        return setmetatable({hkey = buf 'T'}, RegKey)
    end
end

local REG_NONE                    = 0
local REG_SZ                      = 1
local REG_EXPAND_SZ               = 2
local REG_BINARY                  = 3
local REG_DWORD                   = 4
local REG_DWORD_LITTLE_ENDIAN     = 4
local REG_DWORD_BIG_ENDIAN        = 5
local REG_LINK                    = 6
local REG_MULTI_SZ                = 7
local REG_RESOURCE_LIST           = 8
local REG_FULL_RESOURCE_DESCRIPTOR = 9
local REG_RESOURCE_REQUIREMENTS_LIST = 10
local REG_QWORD                   = 11
local REG_QWORD_LITTLE_ENDIAN     = 11

function RegKey:get(value, subkey)
    local buf = malloc(8)
    local ty = malloc(4)
    local len = malloc(4)
    local code
    ::RETRY::
    libffi.write_type(len, 'I4', #buf)
    code = adv.RegGetValueA(self.hkey, subkey, value, 0x0000ffff, ty, buf, len)
    if code == err.ERROR_MORE_DATA then
        buf = malloc(len 'I4')
        goto RETRY
    end
    if code == 0 then
        ty = ty 'I4'
        len = len 'I4'
        if ty == REG_SZ or ty == REG_EXPAND_SZ or ty == REG_BINARY or ty == REG_MULTI_SZ then
            return libffi.string(buf, len - 1), ty
        end
        if ty == REG_DWORD then
            return buf 'I4', ty
        end
        if ty == REG_QWORD then
            return buf 'I8', ty
        end
        -- TODO:
    end
end

function RegKey:enum_key()
    local i = -1
    local buf = malloc(1024)
    return function()
        i = i + 1
        if adv.RegEnumKeyA(self.hkey, i, buf, #buf) == 0 then
            return i, libffi.string(buf)
        end
    end
end

function RegKey:enum_value()
    local i = -1
    local name = malloc(1024)
    local len_ty = malloc(8)
    return function()
        i = i + 1
        libffi.write_type(len_ty, 'I4', #name)
        if adv.RegEnumValueA(self.hkey, i, name, len_ty, 0, len_ty + 4, 0, 0) == 0 then
            local len, ty = libffi.read_pack(len_ty, 'I4I4')
            return i, libffi.string(name, len), ty
        end
    end
end

function RegKey:close()
    if self.hkey then
        adv.RegCloseKey(self.hkey)
        self.hkey = 0
    end
end

RegKey.__gc = RegKey.close
RegKey.__close = RegKey.close

local mod = {
    RegKey = RegKey,
    HKEY_CLASSES_ROOT        = setmetatable({hkey = 0x80000000}, RegKey),
    HKEY_CURRENT_USER        = setmetatable({hkey = 0x80000001}, RegKey),
    HKEY_LOCAL_MACHINE       = setmetatable({hkey = 0x80000002}, RegKey),
    HKEY_USERS               = setmetatable({hkey = 0x80000003}, RegKey),
    HKEY_PERFORMANCE_DATA    = setmetatable({hkey = 0x80000004}, RegKey),
    HKEY_PERFORMANCE_TEXT    = setmetatable({hkey = 0x80000050}, RegKey),
    HKEY_PERFORMANCE_NLSTEXT = setmetatable({hkey = 0x80000060}, RegKey),
}

return mod