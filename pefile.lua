
local class = require 'class'
local PEFile = class {__get = {}}

PEFile.readBytes = read_bytes

-- Constant
-- {{{
PEFile.IMAGE_SCN_TYPE_NO_PAD              = 0x00000008  -- Reserved.
PEFile.IMAGE_SCN_TYPE_COPY                = 0x00000010  -- Reserved.

PEFile.IMAGE_SCN_CNT_CODE                 = 0x00000020  -- Section contains code.
PEFile.IMAGE_SCN_CNT_INITIALIZED_DATA     = 0x00000040  -- Section contains initialized data.
PEFile.IMAGE_SCN_CNT_UNINITIALIZED_DATA   = 0x00000080  -- Section contains uninitialized data.

PEFile.IMAGE_SCN_LNK_OTHER                = 0x00000100  -- Reserved.
PEFile.IMAGE_SCN_LNK_INFO                 = 0x00000200  -- Section contains comments or some other type of information.
PEFile.IMAGE_SCN_TYPE_OVER                = 0x00000400  -- Reserved.
PEFile.IMAGE_SCN_LNK_REMOVE               = 0x00000800  -- Section contents will not become part of image.
PEFile.IMAGE_SCN_LNK_COMDAT               = 0x00001000  -- Section contents comdat.
PEFile.IMAGE_SCN_MEM_PROTECTED            = 0x00004000
PEFile.IMAGE_SCN_NO_DEFER_SPEC_EXC        = 0x00004000  -- Reset speculative exceptions handling bits in the TLB entries for this section.
PEFile.IMAGE_SCN_GPREL                    = 0x00008000  -- Section content can be accessed relative to GP
PEFile.IMAGE_SCN_MEM_FARDATA              = 0x00008000
PEFile.IMAGE_SCN_MEM_SYSHEAP              = 0x00010000
PEFile.IMAGE_SCN_MEM_PURGEABLE            = 0x00020000
PEFile.IMAGE_SCN_MEM_16BIT                = 0x00020000
PEFile.IMAGE_SCN_MEM_LOCKED               = 0x00040000
PEFile.IMAGE_SCN_MEM_PRELOAD              = 0x00080000

PEFile.IMAGE_SCN_ALIGN_1BYTES             = 0x00100000  --
PEFile.IMAGE_SCN_ALIGN_2BYTES             = 0x00200000  --
PEFile.IMAGE_SCN_ALIGN_4BYTES             = 0x00300000  --
PEFile.IMAGE_SCN_ALIGN_8BYTES             = 0x00400000  --
PEFile.IMAGE_SCN_ALIGN_16BYTES            = 0x00500000  -- Default alignment if no others are specified.
PEFile.IMAGE_SCN_ALIGN_32BYTES            = 0x00600000  --
PEFile.IMAGE_SCN_ALIGN_64BYTES            = 0x00700000  --
PEFile.IMAGE_SCN_ALIGN_128BYTES           = 0x00800000  --
PEFile.IMAGE_SCN_ALIGN_256BYTES           = 0x00900000  --
PEFile.IMAGE_SCN_ALIGN_512BYTES           = 0x00A00000  --
PEFile.IMAGE_SCN_ALIGN_1024BYTES          = 0x00B00000  --
PEFile.IMAGE_SCN_ALIGN_2048BYTES          = 0x00C00000  --
PEFile.IMAGE_SCN_ALIGN_4096BYTES          = 0x00D00000  --
PEFile.IMAGE_SCN_ALIGN_8192BYTES          = 0x00E00000  --
PEFile.IMAGE_SCN_ALIGN_MASK               = 0x00F00000

PEFile.IMAGE_SCN_LNK_NRELOC_OVFL          = 0x01000000  -- Section contains extended relocations.
PEFile.IMAGE_SCN_MEM_DISCARDABLE          = 0x02000000  -- Section can be discarded.
PEFile.IMAGE_SCN_MEM_NOT_CACHED           = 0x04000000  -- Section is not cachable.
PEFile.IMAGE_SCN_MEM_NOT_PAGED            = 0x08000000  -- Section is not pageable.
PEFile.IMAGE_SCN_MEM_SHARED               = 0x10000000  -- Section is shareable.
PEFile.IMAGE_SCN_MEM_EXECUTE              = 0x20000000  -- Section is executable.
PEFile.IMAGE_SCN_MEM_READ                 = 0x40000000  -- Section is readable.
PEFile.IMAGE_SCN_MEM_WRITE                = 0x80000000  -- Section is writeable.

-- Reloc Types:
PEFile.IMAGE_REL_BASED_ABSOLUTE              = 0
PEFile.IMAGE_REL_BASED_HIGH                  = 1
PEFile.IMAGE_REL_BASED_LOW                   = 2
PEFile.IMAGE_REL_BASED_HIGHLOW               = 3
PEFile.IMAGE_REL_BASED_HIGHADJ               = 4
PEFile.IMAGE_REL_BASED_MACHINE_SPECIFIC_5    = 5
PEFile.IMAGE_REL_BASED_RESERVED              = 6
PEFile.IMAGE_REL_BASED_MACHINE_SPECIFIC_7    = 7
PEFile.IMAGE_REL_BASED_MACHINE_SPECIFIC_8    = 8
PEFile.IMAGE_REL_BASED_MACHINE_SPECIFIC_9    = 9
PEFile.IMAGE_REL_BASED_DIR64                 = 10

PEFile.IMAGE_DEBUG_TYPE_UNKNOWN          = 0
PEFile.IMAGE_DEBUG_TYPE_COFF             = 1
PEFile.IMAGE_DEBUG_TYPE_CODEVIEW         = 2
PEFile.IMAGE_DEBUG_TYPE_FPO              = 3
PEFile.IMAGE_DEBUG_TYPE_MISC             = 4
PEFile.IMAGE_DEBUG_TYPE_EXCEPTION        = 5
PEFile.IMAGE_DEBUG_TYPE_FIXUP            = 6
PEFile.IMAGE_DEBUG_TYPE_OMAP_TO_SRC      = 7
PEFile.IMAGE_DEBUG_TYPE_OMAP_FROM_SRC    = 8
PEFile.IMAGE_DEBUG_TYPE_BORLAND          = 9
PEFile.IMAGE_DEBUG_TYPE_RESERVED10       = 10
PEFile.IMAGE_DEBUG_TYPE_CLSID            = 11
PEFile.IMAGE_DEBUG_TYPE_VC_FEATURE       = 12
PEFile.IMAGE_DEBUG_TYPE_POGO             = 13
PEFile.IMAGE_DEBUG_TYPE_ILTCG            = 14
PEFile.IMAGE_DEBUG_TYPE_MPX              = 15
PEFile.IMAGE_DEBUG_TYPE_REPRO            = 16

local IMAGE_DIRECTORY_ENTRY =
{
    EXPORT         =  0,   -- Export Directory
    IMPORT         =  1,   -- Import Directory
    RESOURCE       =  2,   -- Resource Directory
    EXCEPTION      =  3,   -- Exception Directory
    SECURITY       =  4,   -- Security Directory
    BASERELOC      =  5,   -- Base Relocation Table
    DEBUG          =  6,   -- Debug Directory
    COPYRIGHT      =  7,   -- (X86 usage)
    ARCHITECTURE   =  7,   -- Architecture Specific Data
    GLOBALPTR      =  8,   -- RVA of GP
    TLS            =  9,   -- TLS Directory
    LOAD_CONFIG    = 10,   -- Load Configuration Directory
    BOUND_IMPORT   = 11,   -- Bound Import Directory in headers
    IAT            = 12,   -- Import Address Table
    DELAY_IMPORT   = 13,   -- Delay Load Import Descriptors
    COM_DESCRIPTOR = 14,   -- COM Runtime descriptor
}

PEFile.Magic = class.enum
{
    HDR32_MAGIC      = 0x10b,
    HDR64_MAGIC      = 0x20b,
    ROM_HDR_MAGIC    = 0x107,
}

PEFile.Machine = class.enum
{
    TARGET_HOST       = 0x0001,
    I386              = 0x014c,
    R3000             = 0x0162,
    R4000             = 0x0166,
    R10000            = 0x0168,
    WCEMIPSV2         = 0x0169,
    ALPHA             = 0x0184,
    SH3               = 0x01a2,
    SH3DSP            = 0x01a3,
    SH3E              = 0x01a4,
    SH4               = 0x01a6,
    SH5               = 0x01a8,
    ARM               = 0x01c0,
    THUMB             = 0x01c2,
    ARMNT             = 0x01c4,
    AM33              = 0x01d3,
    POWERPC           = 0x01F0,
    POWERPCFP         = 0x01f1,
    IA64              = 0x0200,
    MIPS16            = 0x0266,
    ALPHA64           = 0x0284,
    MIPSFPU           = 0x0366,
    MIPSFPU16         = 0x0466,
    TRICORE           = 0x0520,
    CEF               = 0x0CEF,
    EBC               = 0x0EBC,
    AMD64             = 0x8664,
    M32R              = 0x9041,
    ARM64             = 0xAA64,
    CEE               = 0xC0EE,
}

PEFile.Subsystem = class.enum
{
    UNKNOWN                  = 0,
    NATIVE                   = 1,
    WINDOWS_GUI              = 2,
    WINDOWS_CUI              = 3,
    OS2_CUI                  = 5,
    POSIX_CUI                = 7,
    NATIVE_WINDOWS           = 8,
    WINDOWS_CE_GUI           = 9,
    EFI_APPLICATION          = 10,
    EFI_BOOT_SERVICE_DRIVER  = 11,
    EFI_RUNTIME_DRIVER       = 12,
    EFI_ROM                  = 13,
    XBOX                     = 14,
    WINDOWS_BOOT_APPLICATION = 16,
    XBOX_CODE_CATALOG        = 17,
}

PEFile.DllCharacteristics = class.bits
{
    HIGH_ENTROPY_VA       = 0x0020,
    DYNAMIC_BASE          = 0x0040,
    FORCE_INTEGRITY       = 0x0080,
    NX_COMPAT             = 0x0100,
    NO_ISOLATION          = 0x0200,
    NO_SEH                = 0x0400,
    NO_BIND               = 0x0800,
    APPCONTAINER          = 0x1000,
    WDM_DRIVER            = 0x2000,
    GUARD_CF              = 0x4000,
    TERMINAL_SERVER_AWARE = 0x8000,
}
-- }}}

local opt32_fmt = 'I2I1I1I4I4I4I4I4I4I4I4I4I2I2I2I2I2I2I4I4I4I4I2I2I4I4I4I4I4I4'
local opt64_fmt = 'I2I1I1I4I4I4I4I4I8I4I4I2I2I2I2I2I2I4I4I4I4I2I2I8I8I8I8I4I4'

local function PEFile_Unpack(self, format, va)
    local VA = va
    if va > 0x1000 then va = self:VA2Offset(va) end
    assert(va, 'Invaid VirtualAddress ' .. HEX(VA))
    local result = {format:unpack(self.data, va + 1)}
    local count = #result
    result[count] = result[count] - 1
    return table.unpack(result)
end

local function PEMemo_Unpack(self, format, va)
    local ok, size = pcall(format.packsize, format)
    if ok then
        local data = PEFile.readBytes(self.base + va, size)
        if data then
            local result = {format:unpack(data)}
            local count = #result
            result[count] = va + size
            return table.unpack(result)
        end
        error('read "'..format..'" @'..hex(self.base + va))
    else
        return self.read_pack(self.base + va, format)
    end
end

function PEFile:__init(opt, type)
    if not type then
        if math.type(opt) == 'integer' then
            type = 'address'
        elseif #opt <= 260 then
            type = 'string'
            opt = require 'glue'.readfile(opt)
        else
            type = 'string'
        end
    end

    self.read_pack = read_pack
    if type == 'address' then
        self.Unpack = PEMemo_Unpack
        self.base = opt
    else
        self.Unpack = PEFile_Unpack
        self.data = opt
    end

    local fileheader_fmt = 'I2I2I4I4I4I2I2'
    local e_lfanew = self:Unpack('I2', 0x3c)
    self.nt_pos = e_lfanew
    assert(self:Unpack('c4', self.nt_pos) == 'PE\0\0')

    self.file_pos = self.nt_pos + 0x04
    self.opt_pos = self.file_pos + fileheader_fmt:packsize()
    self.Magic = self:Unpack('I2', self.opt_pos)
    self.IS64 = self.Magic == PEFile.Magic.HDR64_MAGIC

    local opt_fmt = self.IS64 and opt64_fmt or opt32_fmt
    self.data_pos = self.opt_pos + opt_fmt:packsize()
    self.sec_pos = self.data_pos + 8 * 16

    -- IMAGE_FILE_HEADER
    local FileHeader = {} self.FileHeader = FileHeader
    FileHeader.Machine, FileHeader.NumberOfSections,
    FileHeader.TimeDateStamp, FileHeader.PointerToSymbolTable,
    FileHeader.NumberOfSymbols, FileHeader.SizeOfOptionalHeader,
    FileHeader.Characteristics = self:Unpack(fileheader_fmt, self.file_pos)
    table.update(self, FileHeader)
    self.sec_pos = self.opt_pos + FileHeader.SizeOfOptionalHeader

    -- IMAGE_OPTIONAL_HEADER
    local opt = {}
    if self.IS64 then
        opt.Magic, opt.MajorLinkerVersion, opt.MinorLinkerVersion,
        opt.SizeOfCode,
        opt.SizeOfInitializedData,
        opt.SizeOfUninitializedData,
        opt.AddressOfEntryPoint,
        opt.BaseOfCode, opt.ImageBase,
        opt.SectionAlignment, opt.FileAlignment,
        opt.MajorOperatingSystemVersion,
        opt.MinorOperatingSystemVersion,
        opt.MajorImageVersion, opt.MinorImageVersion,
        opt.MajorSubsystemVersion, opt.MinorSubsystemVersion,
        opt.Win32VersionValue, opt.SizeOfImage, opt.SizeOfHeaders,
        opt.CheckSum, opt.Subsystem, opt.DllCharacteristics,
        opt.SizeOfStackReserve, opt.SizeOfStackCommit,
        opt.SizeOfHeapReserve, opt.SizeOfHeapCommit,
        opt.LoaderFlags, opt.NumberOfRvaAndSizes = self:Unpack(opt_fmt, self.opt_pos)
    else
        opt.Magic, opt.MajorLinkerVersion, opt.MinorLinkerVersion,
        opt.SizeOfCode,
        opt.SizeOfInitializedData,
        opt.SizeOfUninitializedData,
        opt.AddressOfEntryPoint,
        opt.BaseOfCode, opt.BaseOfData, opt.ImageBase,
        opt.SectionAlignment, opt.FileAlignment,
        opt.MajorOperatingSystemVersion,
        opt.MinorOperatingSystemVersion,
        opt.MajorImageVersion, opt.MinorImageVersion,
        opt.MajorSubsystemVersion, opt.MinorSubsystemVersion,
        opt.Win32VersionValue, opt.SizeOfImage, opt.SizeOfHeaders,
        opt.CheckSum, opt.Subsystem, opt.DllCharacteristics,
        opt.SizeOfStackReserve, opt.SizeOfStackCommit,
        opt.SizeOfHeapReserve, opt.SizeOfHeapCommit,
        opt.LoaderFlags, opt.NumberOfRvaAndSizes = self:Unpack(opt_fmt, self.opt_pos)
    end
    table.update(self, opt)
    self.OptionalHeader = opt
end

function PEFile:GetDataDirectory(which)
    -- debugger()
    which = type(which) == 'string' and IMAGE_DIRECTORY_ENTRY[which:upper()] or which
    local result = {}
    result.VirtualAddress, result.Size = self:Unpack('I4I4', self.data_pos + 0x08 * which)
    return result
end

function PEFile:GetBase()
    return self.base or self.ImageBase
end

function PEFile:GetRelocInfo()
    if self.reloc_list then return self.reloc_list end

    local reloc_data = self:GetDataDirectory 'BASERELOC'
    local offset = reloc_data.VirtualAddress
    if offset == 0 then return end

    local result = {}
    while true do
        local VirtualAddress, SizeOfBlock = self:Unpack('I4I4', offset)
        if VirtualAddress == 0 and SizeOfBlock == 0 then break end

        for i = 8, SizeOfBlock - 2, 2 do
            -- VirtualAddress、Type、[Size]
            local num = self:Unpack('I2', offset + i)
            local item = { VirtualAddress = VirtualAddress + (num & 0x0FFF), Type = num >> 12, }
            if item.Type == 3 then item.Size = 4 end
            table.insert(result, item)
        end
        offset = offset + SizeOfBlock
    end

    self.reloc_list = result
    return result
end

function PEFile.__get:SectionList()
    local offset = self.sec_pos
    local base = self:GetBase()
    local result = {}
    for i = 1, self.FileHeader.NumberOfSections do
        local item = {}
        item.Name, item.VirtualSize,
        item.VirtualAddress,
        item.SizeOfRawData,
        item.PointerToRawData,
        item.PointerToRelocations,
        item.PointerToLinenumbers,
        item.NumberOfRelocations,
        item.NumberOfLinenumbers,
        item.Characteristics,
        offset = self:Unpack('c8I4I4I4I4I4I4I2I2I4', offset)

        item.Name = item.Name:gsub('\0.*$', '')
        item.Address = item.VirtualAddress + base
        table.insert(result, item) result[item.Name] = item
    end
    self.SectionList = result
    return result
end

function PEFile.__get:ExportDirectory()
    local export_data = self:GetDataDirectory 'EXPORT'
    if export_data.VirtualAddress == 0 then return end
    -- IMAGE_EXPORT_DIRECTORY
    local ok, exp = false, {}
    ok, exp.Characteristics,
    exp.TimeDateStamp,
    exp.MajorVersion, exp.MinorVersion,
    exp.Name, exp.Base,
    exp.NumberOfFunctions, exp.NumberOfNames,
    exp.AddressOfFunctions, exp.AddressOfNames,
    exp.AddressOfNameOrdinals = pcall(self.Unpack, self, 'I4I4I2I2I4I4I4I4I4I4I4', export_data.VirtualAddress)
    if ok then
        self.ExportDirectory = exp
        return exp
    end
end

function PEFile.__get:ExportList()
    -- IMAGE_EXPORT_DIRECTORY
    local exp = self.ExportDirectory
    if not exp then return end
    local names = exp.AddressOfNames
    local oridinals = exp.AddressOfNameOrdinals
    local functions = exp.AddressOfFunctions
    -- printx(names, oridinals, functions)
    local base = self:GetBase()
    local result = {}
    for i = 0, exp.NumberOfNames - 1 do
        local item = {}
        item.NameRVA = self:Unpack('I4', names + i * 4)
        item.Name = self:Unpack('z', item.NameRVA)
        item.Number = self:Unpack('I2', oridinals + i * 2)
        item.VirtualAddress = self:Unpack('I4', functions + item.Number * 4)
        if item.VirtualAddress == 0 then break end
        item.Address = base + item.VirtualAddress
        table.insert(result, item)
    end
    self.ExportList = result
    return result
end

function PEFile:GetExportInfo(i, exp)
    exp = exp or self.ExportDirectory
    local item = {}
    local base = self:GetBase()
    item.NameRVA = self:Unpack('I4', exp.AddressOfNames + i * 4)
    item.Name = self:Unpack('z', item.NameRVA)
    item.Number = self:Unpack('I2', exp.AddressOfNameOrdinals + i * 2)
    item.VirtualAddress = self:Unpack('I4', exp.AddressOfFunctions + item.Number * 4)
    item.Address = base + item.VirtualAddress
    return item
end

function PEFile.__get:DebugDirectory()
    local dd = self:GetDataDirectory 'DEBUG'
    if dd.VirtualAddress == 0 then return end
    -- MAGE_DEBUG_DIRECTORY
    local res = {}
    res.Characteristics,
    res.TimeDateStamp,
    res.MajorVersion,
    res.MinorVersion,
    res.Type,
    res.SizeOfData,
    res.AddressOfRawData,
    res.PointerToRawData = self:Unpack('I4I4I2I2I4I4I4I4', dd.VirtualAddress)
    self.DebugDirectory = res
    return res
end

function PEFile.__get:DebugInfo()
    local dd = self.DebugDirectory
    if dd and dd.Type == PEFile.IMAGE_DEBUG_TYPE_CODEVIEW then
        local offset
        local res = {}
        res.codeview_signature,
        res.signature,
        res.age, offset = self:Unpack('I4c16I4', dd.AddressOfRawData)
        res.name = PEFile.readBytes(self.base + offset, dd.SizeOfData - 24 - 1)
        -- if res.name then res.name = res.name:gsub('\0.*', '') end
        -- GUID struct
        local data1, data2, data3, data4 = ('I4I2I2c8'):unpack(res.signature)
        res.pdb_signature = ('%08X%04X%04X%s%X'):format(data1, data2, data3, data4:tohex():upper(), res.age)
        self.DebugInfo = res
        return res
    end
end

function PEFile.__get:ImportList()
    local import_data = self:GetDataDirectory 'IMPORT'
    if import_data.VirtualAddress == 0 then return end

    local imp_fmt = 'I4I4I4I4I4'
    local offset = import_data.VirtualAddress
    local result = {}
    for i = 1, import_data.Size // imp_fmt:packsize() do
        local ok, item = false, {}
        ok, item.Characteristics,
        item.TimeDateStamp,
        item.ForwarderChain,
        item.NameRVA, item.FirstThunk,
        offset = pcall(self.Unpack, self, imp_fmt, offset)
        if not ok or item.FirstThunk == 0 then break end

        item.OriginalFirstThunk = item.Characteristics
        item.Name = self:Unpack('z', item.NameRVA)
        table.insert(result, item)
    end
    self.ImportList = result
    return result
end

function PEFile:EachImportItem(import)
    local offset = import.OriginalFirstThunk
    assert(offset, 'Invaid Import')

    local fmt = self.IS64 and 'I8' or 'I4'
    local original_flag = self.IS64 and 0x8000000000000000 or 0x80000000

    return function()
        local rva
        rva, offset = self:Unpack(fmt, offset)
        if rva == 0 then return end

        local result = {}
        if rva & original_flag ~= 0 then
            -- Import by number
            result.Number = rva & 0x7FFFFFFFFFFFFFFF
        else
            -- Import by function name
            result.Number = self:Unpack('I2', rva)
            result.Name = self:Unpack('z', rva + 2)
        end

        return result
    end
end

function PEFile:VA2Offset(VirtualAddress)
    for i, section in ipairs(self.SectionList) do
        local offset = VirtualAddress - section.VirtualAddress
        -- if offset >= 0 and offset < section.SizeOfRawData then
        if offset >= 0 and offset < section.VirtualSize then
            return section.PointerToRawData + offset
        end
    end
end

function PEFile.FromFile(filepath)
    local file = io.open(filepath, 'rb')
    assert(file)

    return PEFile(file:read 'a')
end

function PEFile.FromString(string)
    return PEFile(string)
end

function PEFile.FromAddress(address)
    assert(type(address) == 'number')
    assert(PEFile.readBytes)
    return PEFile(address)
end

--[[
function PEFile:PrintHeader()
    print('             Magic', PEFile.Magic[self.Magic])
    print('           Machine', PEFile.Machine[self.Machine])
    print('         Subsystem', PEFile.Subsystem[self.Subsystem])
    print('       LinkVersion', self.MajorLinkerVersion .. '.' .. self.MinorLinkerVersion)
    print('        EntryPoint', HEX(self.AddressOfEntryPoint + self.ImageBase))
    print('     TimeDateStamp', HEX(self.TimeDateStamp))
    print('       SizeOfImage', HEX(self.SizeOfImage))
    print('          CheckSum', HEX(self.CheckSum))
    print('DllCharacteristics', PEFile.DllCharacteristics[self.DllCharacteristics])
    print('SizeOfOptionalHeader', hex(self.SizeOfOptionalHeader))
end
]]

return PEFile