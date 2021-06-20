
local mod = {}

mod.parser = [[
asm                          -- assembly a instruction
    <insn>     (string)         the instruction
    <address> (default '')      the address

    --hex                       from hex string
    -w, --write                 assembly and write to address
]]

if not ASM_REVERT then ASM_REVERT = {} end
local revert = ASM_REVERT

function mod.main(args)
    if args.address == '' then
        args.address = 0x1000
    else
        args.address = PA(args.address)
    end

    if args.insn == 'revert' then
        local origin = revert[args.address]
        if origin then
            return log('[asm] revert', write_bytes(args.address, origin))
        end
        return
    end

    local data = args.hex and args.insn:fromhex() or assemble(args.address, args.insn)
    log(hex(args.address) .. ':', data:to_hex())

    if args.write then
        revert[args.address] = read_bytes(args.address, #data)
        log('[asm] write:', write_bytes(args.address, data))
    end
end

return mod