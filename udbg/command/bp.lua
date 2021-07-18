
require 'udbg.alias'

local mod = {}

require('pl.lapp').add_type('bp_type', function(s)
    return assert(string.match(s, '[ewap][1248]'))
end)

mod.parser = [[
bp                                        设置断点
    <address>       (string)              断点地址
    <vars...>       (optional string)     变量列表

    -n, --name        (optional string)   断点名称
    -c, --cond        (optional string)   中断条件
    -l, --log         (optional string)   日志表达式
    -f, --filter      (optional string)   日志条件
    -s, --statistics  (optional string)   统计表达式
    -t, --type        (optional bp_type)  断点类型(e|w|a)(1|2|4|8)
    --tid             (optional number)   命中线程
    --temp                                临时断点
    --symbol                              转换为符号
    --hex                                 十六进制显示
    --caller                              显示调用者
    -m, --module                          模块加载断点
]]
local ui = require 'udbg.uix'

local cmd = function(args)
    local bp_type, bp_size
    if args.type then
        local t, l = string.match(args.type, '([ewa])([1248])')
        bp_type = t == 'e' and 'execute' or t == 'w' and 'write' or t == 'a' and 'access' or t == 'p' and 'table'
        bp_size = tonumber(l)
    end
    if not args.name then args.name = args.address end
    local script = {'local tid, bpid = ...'}
    do  -- build the callback script
        if args.vars and #args.vars > 0 then
            local vars = {}
            for i, v in ipairs(args.vars) do
                local vn = 'v' .. i
                table.insert(vars, vn)
                table.insert(script, 'local ' .. vn .. ' = ' .. v)
            end
            if not args.log then
                args.log = table.concat(vars, ', ')
            end
        end
        if args.filter then
            table.insert(script, 'local filter = ' .. args.filter)
        end
        if args.caller then
            table.insert(script, 'local ret = get_symbol(reg._lr)')
            local expr = '"->", ret'
            args.log = (args.log and args.log .. ', ' .. expr or expr)
        end
        if args.log then
            local prefix = '"[' .. args.name .. ']~" .. reg.tid, '
            local stat = 'log(' .. prefix .. args.log .. ')'
            if args.filter then
                stat = 'if filter then ' .. stat .. ' end'
            end
            table.insert(script, stat)
        elseif args.filter then
            table.insert(script, 'if not filter then return false end')
        end

        local ret = table.concat({args.cond or 'false', args.statistics or 'nil'}, ', ')
        if #ret > 0 then table.insert(script, 'return ' .. ret) end
    end

    local bpid, callback
    if #script > 2 or args.filter or args.statistics then
        ui.warn('breakpoint callback is:')
        for _, line in ipairs(script) do log(' ', line) end

        local counter = args.statistics and ui.count_table
        {
            name = args.name, hex = args.hex, symbol = args.symbol,
            stop = function() del_bp(bpid) end,
        }

        local handler = assert(load(table.concat(script, '\n')))
        callback = function(tid, bpid)
            local interrupt, value = handler(tid, bpid)
            if counter and value then counter(value) end
            return interrupt
        end
    end
    bpid = add_bp(EA(args.address), {
        callback = callback,
        temp = args.temp, tid = args.tid,
        type = bp_type, size = bp_size
    })
    log('add_bp', hex(bpid))
end

function mod.main(args)
    if args.module then
        if not on_module_bp then
            MODULE_BPLIST = {}
            function on_module_bp(base, path)
                for i, args in ipairs(MODULE_BPLIST) do
                    if os.path.basename(path:lower()) == args.module then
                        table.remove(MODULE_BPLIST, i)
                        ui.info('[bp]', args.address)
                        cmd(args)
                    end
                end
            end
            before_global('on_module_load', on_module_bp)
        end

        args.module = args.address:match('^(.-)!'):lower()
        if get_module(args.module) then
            return cmd(args)
        end
        table.insert(MODULE_BPLIST, args)
    else
        return cmd(args)
    end
end

return mod