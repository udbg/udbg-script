
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

local pending_module = {} _ENV.pending_module = pending_module
uevent.on('module-load', function(module)
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
local get_symbol_ = udbg.get_symbol
__fnsize = 0x300

---get symbol by address
---@param a integer @address
---@param a2 boolean|"'offset'"
---@return string
function get_symbol(a, a2)
    if a2 == 'offset' then
        local m, _, _, base = get_symbol_(a, true)
        local offset = a - base
        if m then
            if offset ~= 0 then
                return strfmt('%s+%x', m, offset)
            end
        else
            return m
        end
    else
        return get_symbol_(a, a2 or __fnsize)
    end
end

---dissect a pointer
---@param p integer @the pointer address
---@param ret boolean @parse this pointer as a return point
---@return string @type of this pointer, 'symbol' 'string' 'wstring' 'return'
---@return any
function pointer_info(p, ret)
    local insn = ret and detect_return(p)
    if insn then return 'return', insn end
    local text, wide = detect_string(p)
    if text then return wide and 'wstring' or 'cstring', text end
    local sym = get_symbol(p)
    if sym then return 'symbol', sym end
end

do          -- evaluate address
    local parse_cell, parse_bin, parse_expr
    local type = type

    function parse_cell(expr, pos)
        -- skip white chars
        pos = expr:find('%S', pos)
        if not pos then return end

        -- pointer(...)
        if expr:sub(pos, pos) == '[' then
            local subexp, endp = parse_expr(expr, pos + 1)
            assert(subexp, 'expect a expr')
            assert(expr:sub(endp, endp) == ']', "expect ']' @"..endp)
            return 'read_ptr(' .. subexp .. ')', endp + 1
        end
        -- symbol expression
        local cell = expr:match('[^%+%-%*%s%[%]]+', pos)
        if not cell then
            error('invalid cell: @' .. pos)
        end

        local result
        if cell:match('^0[xX]%x+$') then
            result = cell
        elseif cell:match('^%x+$') then
            result = '0x' .. cell
        else
            local a = parse_address(cell)
            if not a then
                error('invalid symbol: ' .. cell)
            end
            result = hex(a)
        end
        return result, pos + #cell
    end

    function parse_bin(expr, pos)
        -- skip white chars
        pos = expr:find('%S', pos)
        if not pos then return end

        local op = expr:sub(pos, pos)
        if op == '+' or op == '-' or op == '*' then
            local cell, endp = parse_cell(expr, pos + 1)
            return op .. cell, endp
        end
    end

    function parse_expr(expr, pos)
        -- skip white chars
        pos = expr:find('%S', pos)
        if not pos then return end

        local result
        result, pos = parse_cell(expr, pos)
        while expr:sub(pos, pos) do
            local op_expr, endp = parse_bin(expr, pos)
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
    function eval_address(expr, calc)
        if type(expr) ~= 'string' then
            return expr
        end
        calc = calc == nil or calc
        local lexpr = parse_expr(expr, 1)
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

do -------- Extend utf8 ----------
    local u = {}
    local to_utf8 = to_utf8

    function u:__call(s)
        return to_utf8(s)
    end

    setmetatable(utf8, u)
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
    function symbolize(a)
        local sym = get_symbol(a)
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

    local cs = capstone(os.arch)
    local dis = cs.disasm
    function disasm(address)
        local insns = dis(cs, address)
        return insns and insns[1]
    end

    function uevent.on.context_change(psize, arch)
        ui.info('context_change', psize, arch)
        cs = capstone(arch)
        set_psize(psize)
        if udbg.target then
            udbg.target.psize = psize
            udbg.set('capstone', cs)
        end
    end
end