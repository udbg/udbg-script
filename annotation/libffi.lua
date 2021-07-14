
error 'this file should not be execute'

libffi = {}

---load a dynamic library
---@param name string
---@return userdata
function libffi.load(name) end

---create a FuncType or Func
---@param arg string|integer @if arg is integer, return a Func without type info; if arg is string, the types must be provide, and return a FuncType
---@param types? string[] @type of the c function arguments
---@return userdata
function libffi.fn(arg, types) end

---allocate a memory with specific size
---@param size integer
---@return userdata
function libffi.malloc(size) end

---read pack
---@param ptr integer|userdata
---@param fmt string @see string.unpack
---@return ...
function libffi.read_pack(ptr, fmt) end

---write type
---@param ptr integer|userdata
---@param fmt string @see string.pack
---@param val any
function libffi.write_pack(ptr, fmt, val) end

---read bytes from memory directly (lua_pushlstring)
---@param ptr integer|userdata
---@param size integer
---@return string
function libffi.read(ptr, size) end

---write bytes to memory directly (memcpy)
---@param ptr integer|userdata
---@param size? integer
---@return string
function libffi.write(ptr, size) end

---fill memory with value (memset)
---@param ptr integer|userdata
---@param val integer
---@param size integer
---@return string
function libffi.fill(ptr, val, size) end

---read a c-string from memory directly (lua_pushstring)
---@param ptr integer|userdata
---@param size? integer
---@return string
function libffi.string(ptr, size) end