
local mod = {}

mod.parser = [[
r                            -- read/write register
    <reg>   (optional string)   register
    <value> (optional string)   set value
]]

local regs = {
    x86 = {"eax", "ebx", "ecx", "edx", "ebp", "esp", "esi", "edi", "eip", "eflags"},
    x86_64 = {"rax", "rbx", "rcx", "rdx", "rbp", "rsp", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15", "rip", "rflags"},
}

local function show(k)
    logc('gray', ('%5s '):format(k))
    local val = reg[k] or 0
    logc('yellow', fmt_size(val) .. ' ')
    if k == 'rip' or k == 'eip' or k == 'pc' then
        logc('blue', get_symbol(val))
    else
        local c, i = pointer_color_info(val)
        logc(c, i)
    end
    log ''
end

function mod.main(args)
    if args.reg then
        local k = args.reg
        if args.value then
            reg[k] = eval_address(args.value)
        end
        show(k)
    else
        local regs = regs[__llua_arch]
        for _, k in ipairs(regs) do show(k) end
    end
end

return mod