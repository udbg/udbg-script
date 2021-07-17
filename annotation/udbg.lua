
error 'this file should not be execute'

UDbgTarget = {}

-- lua value to pointer(integer)
---@param method integer|string
---@param value any
function ui_notify(method, value) end

-- lua value to pointer(integer)
---@param method integer|string
---@param value any
---@return any
function ui_request(method, value) end

---load lua script from client by RPC
---@param name string
---@return string @full path of the script
---@return string @file content of the script
function __loadremote(name) end

-- enum module
---@return fun():UDbgModule
function enum_module() end

---@class UDbgModule
---@field base integer
---@field size integer
---@field name string
---@field arch string
---@field path string
---@field symbol SymbolFile|nil
---@field entry_point integer
local UDbgModule = {}

function UDbgModule:enum_symbol(name) end

function UDbgModule:enum_export(name) end

function UDbgModule:find_function(address) end

---get symbol info by name
---@param name string
---@return Symbol
function UDbgModule:get_symbol(name) end

---add custome symbol for this module
---@param offset integer
---@param name string
function UDbgModule:add_symbol(offset, name) end

---load symbol file for this module
---@param path string @pdb file path
---@return boolean success
---@return string? error
function UDbgModule:load_symbol(path) end

---@class SymbolFile
local SymbolFile = {}

---get type information
---@param what string|integer
---@return string kind of type
---@return any extra infomation
function SymbolFile:get_type(what) end

function SymbolFile:get_field(type_id) end

function SymbolFile:enum_field(type_id) end

---@class Symbol
---@field name string
---@field uname string
---@field offset integer
---@field len integer
---@field flags integer
---@field type_id integer|nil
local Symbol = {}

---@class UDbgThread
---@field tid integer
---@field teb integer
---@field entry integer
---@field handle integer
---@field error string @last error
---@field name string
---@field status string
---@field priority string
local UDbgThread = {}

---suspend the thread
---@return integer suspend count
function UDbgThread:suspend() end

---resume the thread
function UDbgThread:resume() end

-- get thread list
---@return UDbgThread[]
function thread_list() end

-- open a thread
---@param tid integer
---@return UDbgThread
function open_thread(tid) end

-- get module instance
---@param arg string|integer @specify the module name or base address
---@return UDbgModule
function get_module(arg) end

-- get address by symbol
---@param sym string @the symbol string
---@return integer|nil
function parse_address(sym) end

---@class UDbgBp
---@field address integer

-- get list of breakpoint's id
---@return integer[]
function get_bp_list() end

---@class MemoryPage
---@field base integer
---@field size integer
---@field usage string
---@field alloc_base integer
---@field readonly boolean
---@field writable boolean
---@field executable boolean

---@class UiMemoryPage
---@field base integer
---@field alloc_base integer
---@field size integer
---@field usage string
---@field type string
---@field protect string

-- get list of memory page
---@return UiMemoryPage[]
function get_memory_map() end

-- enum memory page
---@return fun():MemoryPage
function enum_memory() end

-- enum process's handle
---@return fun():integer,integer,string,string @handle,type_index,type_name,name
function enum_handle(pid) end

---@class Capstone
local Capstone = {}
Capstone.__index = Capstone
setmetatable(Capstone, Capstone)

---@class Insn
---@field string string
---@field mnemonic string

---@class InsnDetail
---@field groups integer
---@field read integer
---@field write integer
---@field prefix integer
---@field opcode integer

---disasm
---@param self Capstone
---@param arg integer|string @address or binary
---@param a2 integer|nil @address if arg is binary
function Capstone:disasm(arg, a2) end

---instruction's detail
---@param self Capstone
---@param insn Insn
---@return InsnDetail
function Capstone:detail(insn) end

---new capstone instance
---@param arch string|"'x86'"|"'x86_64'"|"'arm'"|"'arm64'"
---@param mode nil|string|"'32'"|"'64'"|"'arm'"|"'thumb'"
---@return Capstone
function capstone(arch, mode) end

---query virtual address
---@param address integer
---@return MemoryPage
function virtual_query(address) end

---read C string, terminated with '\0'
---@param address integer
---@param max_size? integer
function read_string(address, max_size) end

function read_bytes(address, size) end

function write_bytes(address, bytes) end

function enum_psinfo() end

function detect_return(pointer) end

function detect_string(pointer) end

---read multi value by pack format
---@param address integer
---@param fmt string @see string.unpack
function read_pack(address, fmt) end

---@class Regs
reg = {}
