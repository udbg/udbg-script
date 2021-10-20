
local serpent = require 'serpent'

function pointer_color_info(p, ret)
    local t, info = pointer_info(p, ret)
    local color = 'green'
    if t == 'wstring' then
        info = 'L' .. serpent.line(info)
    elseif t == 'cstring' then
        info = serpent.line(info)
    elseif t == 'symbol' then
        color = 'blue'
    elseif t == 'return' then
        color = 'red'
    else info = nil end
    return color, info, t
end

function enum_psinfo()
    return udbg.engine.default:enum_process()
end

function errno_assert(b, err, ...)
    if not b and err then
        local text, code = get_last_error()
        err = err .. ': ' .. code .. '(' .. text .. ')'
    end
    return assert(b, err, ...)
end

local pending_module = {} _ENV.pending_module = pending_module
uevent.on('targetModuleLoad', function(module)
    local i = 1
    while i <= #pending_module do
        local pm = pending_module[i]
        local m = get_module(pm.name)
        if m and m.base == module.base then
            ui.info('[module callback]', pm.name, tostring(pm.callback))
            pm.callback(m)
            if pm.once then
                table.remove(pending_module, i)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end)

function module_callback(name, callback, opt)
    local m = get_module(name)
    -- options
    local once
    if opt then
        once = opt.once
    end
    if m then
        callback(m)
    end
    if not once or not m then
        table.insert(pending_module, {name = name, callback = callback, once = once})
    end
end

local strfmt = string.format
local get_symbol_ = UDbgTarget.get_symbol
__fnsize = 0x300

---get symbol by address
---@param a integer @address
---@param a2 boolean|"'offset'"
---@return string
function UDbgTarget:get_symbol(a, a2)
    if a2 == 'offset' then
        local m, _, _, base = get_symbol_(self, a, true)
        local offset = a - base
        if m then
            if offset ~= 0 then
                return strfmt('%s+%x', m, offset)
            end
        else
            return m
        end
    else
        return get_symbol_(self, a, a2 or __fnsize)
    end
end

---dissect a pointer
---@param p integer @the pointer address
---@param ret boolean @parse this pointer as a return point
---@return string @type of this pointer, 'symbol' 'string' 'wstring' 'return'
---@return any
function UDbgTarget:pointer_info(p, ret)
    local insn = ret and self:detect_return(p)
    if insn then return 'return', insn end
    local text, wide = self:detect_string(p)
    if text then return wide and 'wstring' or 'cstring', text end
    local sym = self:get_symbol(p)
    if sym then return 'symbol', sym end
end

do          -- evaluate address
    local parse_cell, parse_bin, parse_expr
    local type = type

    function parse_cell(target, expr, pos)
        -- skip white chars
        pos = expr:find('%S', pos)
        if not pos then return end

        -- pointer(...)
        if expr:sub(pos, pos) == '[' then
            local subexp, endp = parse_expr(target, expr, pos + 1)
            assert(subexp, 'expect a expr')
            assert(expr:sub(endp, endp) == ']', "expect ']' @"..endp)
            return 'read_ptr(' .. subexp .. ')', endp + 1
        end
        local cell = expr:match([[%b'']], pos) or expr:match([[%b""]], pos)
        if cell then
            if cell:sub(#cell) ~= cell:sub(1, 1) then
                error('string not closed: ' .. cell)
            end
        end
        -- symbol expression
        cell = cell or expr:match('[^%+%-%*%s%[%]]+', pos)
        if not cell then
            error('invalid cell: @' .. pos)
        end

        local t = cell:find'^[\'"]' and cell:sub(2, -2) or cell
        local result
        if t:match('^0[xX]%x+$') then
            result = t
        elseif t:match('^%x+$') then
            result = '0x' .. t
        else
            local a = target:parse_address(t)
            if not a then
                local m, sym = t:splitv '!'; m = m or t
                m = m == '$exe' and target.image or target:get_module(m)
                assert(m, 'invalid symbol: ' .. t)
                if sym then
                    sym = sym == '$entry' and m.entry or m:get_symbol(sym)
                else
                    sym = 0
                end
                a = m.base + sym
            end
            result = hex(a)
        end
        return result, pos + #cell
    end

    function parse_bin(target, expr, pos)
        -- skip white chars
        pos = expr:find('%S', pos)
        if not pos then return end

        local op = expr:sub(pos, pos)
        if op == '+' or op == '-' or op == '*' then
            local cell, endp = parse_cell(target, expr, pos + 1)
            return op .. cell, endp
        end
    end

    function parse_expr(target, expr, pos)
        -- skip white chars
        pos = expr:find('%S', pos)
        if not pos then return end

        local result
        result, pos = parse_cell(target, expr, pos)
        while expr:sub(pos, pos) do
            local op_expr, endp = parse_bin(target, expr, pos)
            if not op_expr then break end
            result = result..op_expr
            pos = endp
        end
        return result, pos
    end

    ---compile a address expression to lua function
    ---@param expr string
    ---@param calc boolean|nil
    ---@return function|integer @lua function or its result
    ---@return string @converted lua script
    function UDbgTarget:eval_address(expr, calc)
        if type(expr) ~= 'string' then
            return expr
        end
        calc = calc == nil or calc
        local lexpr = parse_expr(self, expr, 1)
        if not lexpr then
            error('invalid address expression: ' .. expr)
        end
        local fun = load('return ' .. lexpr, lexpr)
        if calc then
            return fun(), lexpr
        else
            return fun, lexpr
        end
    end
end

do -------- Extend global --------
    function searchpath(name, path)
        return package.searchpath(name, path or package.path)
    end

    function is_integer(x)
        return math.type(x) == 'integer'
    end

    local format = string.format
    local addr_fmt, size_fmt
    function fmt_addr(a) return format(addr_fmt, a) end
    function fmt_size(a) return format(size_fmt, a) end
    function UDbgTarget:fmt_addr_sym(a)
        local sym = self:get_symbol(a)
        a = fmt_addr(a)
        return sym and a..'('..sym..')' or a
    end
    function set_psize(psize)
        addr_fmt = psize == 8 and '%012X' or '%08X'
        size_fmt = psize == 8 and '%016X' or '%08X'
        read_ptr = psize == 8 and read_u64 or read_u32
        write_ptr = psize == 8 and write_u64 or write_u32
    end
    set_psize(__llua_psize)

    local cs = Capstone.new(os.arch)
    local dis = cs.disasm
    function disasm(address)
        local insns = dis(cs, address)
        return insns and insns[1]
    end

    function enum_disasm(a, max)
        local n = max or 1000
        return function()
            if n == 0 then return end
            local insn = disasm(a)
            if insn then
                a = a + insn.size
            end
            n = n - 1
            return insn
        end
    end

    function uevent.on.context_change(psize, arch)
        ui.info('context_change', psize, arch)
        cs = Capstone.new(arch)
        set_psize(psize)
        if udbg.target then
            udbg.target.psize = psize
            udbg.set('Capstone.new', cs)
        end
    end
end