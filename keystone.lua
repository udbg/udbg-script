
local class = require 'class'
local libffi = require 'libffi'

local mod = {
    KeyStone = class {__set = {}},

    KS_API_MAJOR = 0,
    KS_API_MINOR = 9,

    KS_ARCH_ARM = 1,
    KS_ARCH_ARM64 = 2,
    KS_ARCH_MIPS = 3,
    KS_ARCH_X86 = 4,
    KS_ARCH_PPC = 5,
    KS_ARCH_SPARC = 6,
    KS_ARCH_SYSTEMZ = 7,
    KS_ARCH_HEXAGON = 8,
    KS_ARCH_MAX = 9,

    KS_OPT_SYNTAX = 1,

    OPT_SYNTAX = class.bits {
        INTEL = 1,
        ATT = 2,
        NASM = 4,
        MASM = 8,
        GAS = 16,
    },

    MODE_LITTLE_ENDIAN = 0,
    MODE_BIG_ENDIAN = 1073741824,
    MODE_ARM = 1,
    MODE_THUMB = 16,
    MODE_V8 = 64,
    MODE_MICRO = 16,
    MODE_MIPS3 = 32,
    MODE_MIPS32R6 = 64,
    MODE_MIPS32 = 4,
    MODE_MIPS64 = 8,
    MODE_16 = 2,
    MODE_32 = 4,
    MODE_64 = 8,
    MODE_PPC32 = 4,
    MODE_PPC64 = 8,
    MODE_QPX = 16,
    MODE_SPARC32 = 4,
    MODE_SPARC64 = 8,
    MODE_V9 = 16,

    ERR = class.bits {
        ASM = 128,
        ASM_ARCH = 512,
        OK = 0,
        NOMEM = 1,
        ARCH = 2,
        HANDLE = 3,
        MODE = 4,
        VERSION = 5,
        OPT_INVALID = 6,
        ASM_EXPR_TOKEN = 128,
        ASM_DIRECTIVE_VALUE_RANGE = 129,
        ASM_DIRECTIVE_ID = 130,
        ASM_DIRECTIVE_TOKEN = 131,
        ASM_DIRECTIVE_STR = 132,
        ASM_DIRECTIVE_COMMA = 133,
        ASM_DIRECTIVE_RELOC_NAME = 134,
        ASM_DIRECTIVE_RELOC_TOKEN = 135,
        ASM_DIRECTIVE_FPOINT = 136,
        ASM_DIRECTIVE_UNKNOWN = 137,
        ASM_VARIANT_INVALID = 138,
        ASM_DIRECTIVE_EQU = 139,
        ASM_EXPR_BRACKET = 140,
        ASM_SYMBOL_MODIFIER = 141,
        ASM_SYMBOL_REDEFINED = 142,
        ASM_SYMBOL_MISSING = 143,
        ASM_RPAREN = 144,
        ASM_STAT_TOKEN = 145,
        ASM_UNSUPPORTED = 146,
        ASM_MACRO_TOKEN = 147,
        ASM_MACRO_PAREN = 148,
        ASM_MACRO_EQU = 149,
        ASM_MACRO_ARGS = 150,
        ASM_MACRO_LEVELS_EXCEED = 151,
        ASM_MACRO_STR = 152,
        ASM_ESC_BACKSLASH = 153,
        ASM_ESC_OCTAL = 154,
        ASM_ESC_SEQUENCE = 155,
        ASM_ESC_STR = 156,
        ASM_TOKEN_INVALID = 157,
        ASM_INSN_UNSUPPORTED = 158,
        ASM_FIXUP_INVALID = 159,
        ASM_LABEL_INVALID = 160,
        ASM_INVALIDOPERAND = 512,
        ASM_MISSINGFEATURE = 513,
        ASM_MNEMONICFAIL = 514,
    },
}

local ks = assert(libffi.load 'keystone', 'keystone not found')

local KeyStone = mod.KeyStone
local ArchMode = {
    x86 = {mod.KS_ARCH_X86, mod.MODE_32},
    x86_64 = {mod.KS_ARCH_X86, mod.MODE_64},
    arm = {mod.KS_ARCH_ARM, mod.MODE_ARM},
    aarch64 = {mod.KS_ARCH_ARM64, mod.MODE_LITTLE_ENDIAN},
}
ArchMode.arm64 = ArchMode.aarch64
mod.ArchMode = ArchMode

function KeyStone:__init(arch, mode)
    local pre = ArchMode[arch]
    local buf = libffi.mem(__llua_psize)
    buf.T = 0
    local err = 0
    if pre then
        err = ks.ks_open(pre[1], pre[2], buf)
    else
        err = ks.ks_open(arch, mode, buf)
    end
    assert(err == 0, mod.ERR[err])
    self.handle = buf 'T'
end

function KeyStone:__gc()
    if self.handle then
        ks.ks_close(self.handle)
        self.handle = nil
    end
end

KeyStone.close = KeyStone.__gc
KeyStone.__close = KeyStone.__gc

function KeyStone.__set:syntax(val)
    val = assert(type(val) == 'string' and mod.OPT_SYNTAX[val] or val, 'invalid syntax')
    return ks.ks_option(self.handle, mod.KS_OPT_SYNTAX, val)
end

function KeyStone:asm(str, address)
    assert(type(str) == 'string')
    local buf = libffi.mem(__llua_psize * 3)
    libffi.fill(buf, 0, #buf)
    local err = ks.ks_asm(self.handle, str, address, buf, buf + __llua_psize, buf + __llua_psize * 2)
    if err == 0 then
        local ptr, len, stat_count = libffi.read_pack(buf, 'TTT')
        local res = libffi.read(ptr, len)
        ks.ks_free(ptr)
        return res, stat_count
    else
        return nil, mod.ERR[err]
    end
end

return mod