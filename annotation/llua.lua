
error 'this file should not be execute'

---@type string | "'windows'" | "'linux'" | "'android'"
__llua_os = ''
---@type string @Arch of CPU
__llua_arch = ''
---@type integer @pointer width, in bytes
__llua_psize = 8

---@type string | "'linux'" | "'macos'" | "'ios'" | "'freebsd'" | "'dragonfly'" | "'netbsd'" | "'openbsd'" | "'solaris'" | "'android'" | "'windows'"
os.name = ''
---@type string | "'x86'" | "'x86_64'" | "'arm'" | "'aarch64'" | "'mips'" | "'mips64'" | "'powerpc'" | "'powerpc64'" | "'riscv64'" | "'s390x'" | "'sparc64'"
os.arch = ''
---@type string | "'windows'" | "'unix'"
os.family = ''

---get the file name where caller defined
---@return string
function __file__() end

-- lua value to pointer(integer)
---@param val any
---@return integer
function topointer(val) end

---bind some value to c function
---@param cfn function
---@vararg any @values to bind
function cclosure(cfn, ...) end

---read a file
---@param path string @utf8 encoding
---@return string @data bytes
function readfile(path) end

---write file
---@param path string @utf8 encoding
---@param data string @data bytes
function writefile(path, data) end

os.path = {}

---enum path by specific pattern
---@param wildcard string
---@return fun():string
function os.glob(wildcard) end

---get the executing program's path
---@return string
function os.getexe() end

function os.getcwd() end

function os.chdir(dir) end

function os.env(var) end

function os.putenv(var, val) end

function os.mkdir(path) end

function os.rmdir(dir) end

function os.mkdirs(path) end

---get the directory of path
---@param path string
---@return string?
function os.path.dirname(path) end

---detect if a path is exists
---@param path string
---@return boolean
function os.path.exists(path) end

---get the absolute path
---@param path string
---@return string
function os.path.abspath(path) end

function os.path.basename(path) end

---split extension name
---@param path string
---@return string,string
function os.path.splitext(path) end

---set path extension to @ext
---@param path string
---@param ext string
---@return string
function os.path.withext(path, ext) end

function os.path.join(dir, ...) end

function os.path.isabs(path) end

function os.path.isdir(path) end

function os.path.isfile(path) end

function os.path.meta(path) end

thread = {}

---@class Thread
---@field id integer
---@field name string
---@field handle integer

---spawn a thread with specific lua function
---@param fn function
---@return Thread
function thread.spawn(fn) end

---sleep in current thread
---@param ms integer
function thread.sleep(ms) end

function thread.yield_now() end

---@class LLuaCondvar
local condvar = {}

function condvar:notify_one(any) end

function condvar:notify_all(any) end

function condvar:wait(timeout) end

---create a condition variable
---@return LLuaCondvar
function thread.condvar() end

---convert utf8 string to utf16(le)
---@param utf8 string @utf8 encoding
---@return string @utf16 encoding
function string.to_utf16(utf8) end

---convert utf16 string to utf8
---@param utf16 string @utf16 encoding
---@return string @utf8 encoding
function string.from_utf16(utf16) end