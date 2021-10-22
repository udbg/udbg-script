
-- https://yara.readthedocs.io/en/stable/writingrules.html

local mod = {}

mod.parser = [[
yara                             -- Search Memory use Yara
    <file> (string)                 Yara file | Pattern string
    --start (optional number)       Start Address
    --stop  (optional number)       Stop Address
    --max  (optional number)        Max count
    -m, --module (optional string)  Search in this module
    -b, --binary                    Search binary pattern
    -a, --ascii                     Search string pattern
    -u, --utf16le
    -r, --rule                      file is a rule

example:
    yara -a abcdefghi
    yara -b 'FF 25 ?? ?? ?? ??' -m ntdll
]]

local ui = require 'udbg.ui'
local bin = [[
rule bin {
    strings: $a = {$bin}
    condition: $a
}
]]
local str = [[
rule str {
    strings: $a = "$bin"
    condition: $a
}
]]
local rule = [[
rule _ {
    strings: $a = $rule
    condition: $a
}
]]
local preclude = {
    _pe = [[
rule IsPE {
    condition:
        // MZ signature at offset 0 and ...
        uint16(0) == 0x5A4D and
        // ... PE signature at offset stored in MZ header at 0x3C
        uint32(uint32(0x3C)) == 0x00004550
}
]]
}

function mod.main(args, out)
    out.title = {'rule', 'address', 'length', 'symbol'}
    out.width = {5, 18, 8, 20}

    if args.binary then
        args.rules = bin:gsub('$bin', args.file)
    elseif args.ascii then
        args.rules = str:gsub('$bin', args.file)
    elseif args.utf16le then
        args.rules = bin:gsub('$bin', args.file:to_utf16():to_hex())
    elseif args.rule then
        args.rules = rule:gsub('$rule', args.file)
    else
        if args.file == '$clipboard' then
            args.rules = ui.clipboard()
        else
            local rules = preclude[args.file]
            args.rules = rules or ui.readfile(args.file)
        end
        assert(args.rules, 'readfile failed')
    end
    ui.logc('yellow', args.rules) log('')

    args.start = args.start and EA(args.start)
    args.stop = args.stop and EA(args.stop)

    require 'udbg.search'
    local target = assert(udbg.target)
    require 'udbg.task'.spawn(function(task)
        function args.callback(rule, address, len)
            out(rule, fmt_addr(address), hex(len), target:get_symbol(address))
        end
        function args.progress(p)
            out.progress = p * 100
        end
        function task.try_abort()
            args.abort = true
        end
        local err, reason = target:yara_search(args)
        if err then
            ui.error('[yara]', 'errcode:', err, reason)
        else
            log('[yara]', 'search', args.abort and 'abort.' or 'done.')
        end
    end, {name = 'yara search'})
end

return mod