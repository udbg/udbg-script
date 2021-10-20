
local mod = {}

mod.parser = [[
asm                          --     assembly a instruction
    <insn>    (string)              the instruction
    <address> (optional address)    the address

    --arch    (optional string)
    --hex                       from hex string
    -w, --write                 assembly and write to address
]]

if not ASM_REVERT then ASM_REVERT = {} end
local revert = ASM_REVERT

---assemble a statement
---@param address integer
---@param asm string
---@param arch string|nil
---@return string
function mod.assemble(address, asm, arch)
end

local ok, ks = pcall(require, 'keystone')
if ok then
    function mod.assemble(address, asm, arch)
        local k = ks.KeyStone(arch or os.arch)
        return k:asm(asm, address)
    end
else
    ui.session(function()
        local ks = require 'keystone'
        local service = require 'udbg.service'
        function service.assemble(address, asm, arch)
            local k = ks.KeyStone(arch)
            return k:asm(asm, address)
        end
    end)
    function mod.assemble(address, asm, arch)
        ui.session:request('assemble', {address, asm, arch or os.arch})
    end
end

function mod.main(args)
    args.address = args.address or 0x1000

    if args.insn == 'revert' then
        local origin = revert[args.address]
        if origin then
            return log('[asm] revert', write_bytes(args.address, origin))
        end
        return
    end

    local data = args.hex and args.insn:fromhex() or mod.assemble(args.address, args.insn, args.arch)
    log(hex(args.address) .. ':', data:to_hex())

    if args.write then
        revert[args.address] = read_bytes(args.address, #data)
        log('[asm] write:', write_bytes(args.address, data))
    end
end

return mod