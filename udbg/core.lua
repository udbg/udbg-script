
local ui = require 'udbg.ui'
local event = require 'udbg.event'

-- udbg.config is permanent config
udbg.config = {
    ignore_initbp = false,
    ignore_all_exception = false,
    pause_thread_create = false,
    pause_thread_exit = false,
    pause_module_load = false,
    pause_module_unload = false,
    pause_process_create = false,
    pause_process_exit = false,
    print_exception = true,
    bp_process_entry = false,
    bp_module_entry = false,
    show_debug_string = true,
    backup_breakpoint = true,
}
-- __config is temporary config
__config = setmetatable({}, {__index = udbg.config})

do          -- breakpoint
    local bp_callback = {}
    local bp_extra_info = {}
    function on_breakpoint(tid, bp_id)
        local callback = bp_callback[bp_id]
        local pause = true
        if callback then pause = callback(tid, bp_id) end
        if pause then
            local r1, r2 = event.fire('breakpoint', bp_id)
            if not r1 then
                r1, r2 = ui.pause('Breakpoint~'..tid..': '..hex(bp_id))
            end
            return r1, r2
        end
    end

    local add_bp_, del_bp_, set_bp_ = udbg.add_bp_, udbg.del_bp_, udbg.set_bp_
    local pending_bp = {} _ENV.pending_bp = pending_bp

    event.on('module-load', function()
        for symbol, opt in pairs(pending_bp) do
            if parse_address(symbol) then
                opt.auto = false
                log('[bp]', symbol, hex(add_bp(opt)))
                -- to remove
                table.insert(pending_bp, symbol)
            end
        end
        -- remove the symbol be found
        for _ = 1, #pending_bp, 1 do
            local key = table.remove(pending_bp)
            pending_bp[key] = nil
        end
    end)

    function add_bp(a, opt, arg3)
        if type(a) == 'table' then
            opt = a
            a = opt.address
        end

        local enable = true
        local callback, bp_type, bp_size, temp, tid
        if type(opt) == 'function' then
            callback = opt
            opt = arg3
        end
        if type(opt) == 'table' then
            callback = callback or opt.callback
            bp_type = opt.type
            bp_size = opt.size or 1
            enable = opt.enable == nil or opt.enable
            temp, tid = opt.temp, opt.tid
        end

        local address = parse_address(a)
        if not address then
            opt = opt or {}
            if type(a) == 'string' and opt.auto then
                opt.callback = callback
                opt.address = a
                pending_bp[a] = opt
                return nil, 'pending'
            else
                error 'invalid address'
            end
        end

        local id, err = add_bp_(address, bp_type, bp_size, temp, tid)
        if err == 'exists' then
            del_bp(address)
            id, err = add_bp_(address, bp_type, bp_size, temp, tid)
        end

        if id then
            set_bp(id, 'enable', enable)
            set_bp(id, 'callback', callback)
            -- for target data
            if not callback then
                local m = get_module(address)
                if m then
                    bp_extra_info[id] = {
                        module = m.name,
                        type = bp_type,
                        rva = address - m.base,
                        symbol = get_symbol(address),
                    }
                end
            end
        end

        return id, err
    end

    function set_bp(id, key, val)
        if key == 'callback' then
            local t = type(val)
            assert(t == 'function' or t == 'nil')
            bp_callback[id] = val
        else
            return set_bp_(id, key, val)
        end
    end

    function del_bp(id)
        id = parse_address(id)
        if not id then error 'invalid address' end

        del_bp_(id)
        bp_callback[id] = nil
    end

    function get_bp(id, ...)
        local key = ... or 'callback'
        if key == 'callback' then
            return bp_callback[id]
        elseif key == 'extra' then
            return bp_extra_info[id]
        else
            return get_bp_(id, ...)
        end
    end
end

do
    local INIT_BP<const> = 1
    local BP<const> = 2
    local PS_CREATE<const> = 3
    local PS_EXIT<const> = 4
    local THREAD_CREATE<const> = 5
    local THREAD_EXIT<const> = 6
    local MODULE_LOAD<const> = 7
    local MODULE_UNLOAD<const> = 8
    local EXCEPTION<const> = 9
    local EV_STEP<const> = 10

    local function on_target_success()
        local target = udbg.target
        ui.notify('fire_event', {'target-success', {
            pid = target.pid,
            psize = target.psize,
            os = os.name,
            arch = target.arch,
            path = target.path,
            os_psize = __llua_psize
        }})
        local opt = event.fire 'before-target-success'
        local target_name = opt and opt.target_name
        if not target_name then
            target_name = os.path.basename(udbg.target.path)
            if udbg.target 'wow64' then
                target_name = target_name .. '.wow64'
            end
        end
        __data_dir = __ui_data_dir .. '/' .. target_name
        assert(ui.make_dir(__data_dir))
        ui.info('[data]', __data_dir)
        event.fire('context-change', target.psize, target.arch)
        event.fire('target-success')
        ui.info('[config]', __config)
        ui.continue()
    end

    local function on_initbp(tid)
        local r1, r2 = event.fire 'init-bp'
        if __config.ignore_initbp then
            ui.warn('[ignore_initbp]', true)
        elseif not r1 then
            r1, r2 = ui.pause('InitBp~'..tid)
        end
        if __config.bp_process_entry then
            local m = get_module()
            if m then
                add_bp(m.entry_point, {temp = true})
            else
                ui.error('[initbp]', 'entry not found')
            end
        end
        return r1, r2
    end

    local excp, ignore
    if os.name == 'windows' then
        excp = require 'win.const'.exception
        ignore = {
            [excp.STATUS_CPP_EH_EXCEPTION] = true,
            [excp.STATUS_CLR_EXCEPTION] = true,
            [excp.RPC_S_SERVER_UNAVAILABLE] = true,
            [0x4242420] = true,
        }
    else
        excp = require 'nix.const'.signal
        ignore = {
            [excp.SIGPWR] = true,
            [excp.SIGXCPU] = true,
            [excp.SIGSEGV] = true,
            [excp.SIGCHLD] = true,
        }
    end
    local function on_exception(tid, code, first)
        local reply, arg = event.fire('exception', tid, code, first)
        if reply then return reply, arg end

        local desc = excp[code]
        desc = desc and desc .. '(' .. hex(code) .. ')' or hex(code)
        local second = not first
        if __config.print_exception ~= false then
            local what, addr
            if second then second = '[second]' end
            if os.name == 'windows' then
                if code == excp.STATUS_ACCESS_VIOLATION or code == excp.STATUS_IN_PAGE_ERROR then
                    local t = {[0] = 'read', [1] = 'write', [8] = 'DEP'}
                    what, addr = udbg.eparam(0), udbg.eparam(1)
                    what = '[' .. (t[what] or hex(what)) .. ']'
                    addr = fmt_addr_sym(addr)
                end
            end
            ui.warn('[exception]~' .. tid, hex(reg._pc), desc, second, what, addr)
        end
        if __config.ignore_all_exception then
            return
        end
        local ignore_exception = __config.ignore_exception or ignore
        if second or not ignore_exception[code] then
            return ui.pause('Exception~'..tid..': '..desc)
        end
    end

    local function on_thread_create(tid)
        local t = open_thread(tid)
        local info = ''
        if t and t.teb > 0 then info = hex(t.teb) end
        if t and t.name then info = t.name end
        ui.info('[thread_create]', tid, info)
        if __config.pause_thread_create then
            return ui.pause('ThreadCreate')
        end
    end
    local function on_thread_exit(tid, code)
        ui.info('[thread_exit]', tid, code)
        if __config.pause_thread_exit then
            return ui.pause('ThreadExit')
        end
    end
    local function on_module_load(m)
        event.fire('module-load', m)
        ui.info('[module_load]', hex(m.base), m.path)
        if __config.bp_module_entry then
            add_bp(m.entry_point, {temp = true})
        end
        if __config.pause_module_load then
            return ui.pause('ModuleLoad')
        end
    end
    local function on_module_unload(m)
        event.fire('module-unload', m)
        ui.info('[module_unload]', hex(m.base), m.name)
        if __config.pause_module_unload then
            return ui.pause('ModuleUnload')
        end
    end
    local function on_process_create(pid)
        event.fire('process-create', pid)
        ui.info('[process_create]', pid)
        if __config.pause_process_create then
            return ui.pause('ProcessCreate')
        end
    end
    local function on_process_exit(pid, code)
        event.fire('process-exit', pid, code)
        ui.info('[process_exit]', pid, code)
        if __config.pause_process_exit then
            return ui.pause('ProcessExit')
        end
    end

    udbg.event_handler = table {
        [INIT_BP] = on_initbp,
        [BP] = on_breakpoint,
        [PS_CREATE] = on_process_create,
        [PS_EXIT] = on_process_exit,
        [THREAD_CREATE] = on_thread_create,
        [THREAD_EXIT] = on_thread_exit,
        [MODULE_LOAD] = on_module_load,
        [MODULE_UNLOAD] = on_module_unload,
        [EXCEPTION] = on_exception,
        [EV_STEP] = function(tid)
            local r1, r2 = event.fire('step')
            if not r1 then
                r1, r2 = ui.pause('Step~'..tid)
            end
            return r1, r2
        end,
    }
    udbg.event_id = table {
        [INIT_BP] = 'InitBp',
        [BP] = 'Breakpoint',
        [PS_CREATE] = 'ProcessCreate',
        [PS_EXIT] = 'ProcessExit',
        [THREAD_CREATE] = 'ThreadCreate',
        [THREAD_EXIT] = 'ThreadExit',
        [MODULE_LOAD] = 'ModuleLoad',
        [MODULE_UNLOAD] = 'ModuleUnload',
        [EXCEPTION] = 'Exception',
        [EV_STEP] = 'Step',
    }
    udbg.event_id:swap_key_value(true)
    udbg.traceable_event = {
        [BP] = true,
        [EV_STEP] = true,
        [EXCEPTION] = true,
    }

    local xpcall = xpcall
    local traceback = debug.traceback

    function pcallcall(name, fun, ...)
        local ok, err = xpcall(fun, traceback, ...)
        if not ok then
            ui.error(name, err)
        end
        return ok, err
    end

    ---@class UDbgOpt
    ---@field target string
    ---@field open boolean
    ---@field attach boolean
    udbg.dbgopt = {}

    ---@class UDbgTarget
    ---@field pid integer
    ---@field psize integer
    ---@field arch string
    ---@field path string
    ---@field status string @readonly "idle" "opened" "attached" "paused" "running" "ended"
    ---@field image_base integer

    ---start a debug session
    ---@param opt UDbgOpt
    function udbg.start(opt)
        if udbg.target then error 'target exists' end

        udbg.dbgopt = table.copy(opt)
        __debug_thread = thread.spawn(function()
            local ok, err = pcall(function()
                local handler_table = udbg.event_handler
                local event_id = udbg.event_id
                local ok, err, target, continue_event

                ---@type UDbgTarget
                udbg.target = opt
                ok, target, continue_event = pcall(udbg.create, opt)
                if not ok then
                    err = target
                    event.fire('target-failure', err)
                    udbg.target = nil
                    return
                end

                -- cached function
                local co_create, co_resume = coroutine.create, coroutine.resume
                local co_status = coroutine.status
                -- event data
                local tid, eid, a1, a2, a3, a4
                -- trace data
                local trace_routine, trace_tid

                udbg.set('target', target[1])
                udbg.target, udbg.event_args = target, {}
                local event_meta = {}
                setmetatable(udbg.event_args , event_meta)

                pcallcall('[on_target_success]', on_target_success)
                do      -- event data
                    function event_meta:__index(k)
                        if k == 'trace_tid' then
                            return trace_tid
                        end
                        if k == 'eid' then
                            return eid
                        end
                        if k == 'name' then
                            return event_id[eid] or hex(eid)
                        end
                        if k == 1 then return a1 end
                        if k == 2 then return a2 end
                        if k == 3 then return a3 end
                        if k == 4 then return a4 end
                        if k == 'trace_routine' then
                            return trace_routine
                        end
                    end

                    function event_meta:__newindex(k, v)
                        if k == 'trace_routine' then
                            trace_routine = co_create(v)
                        elseif k == 'trace_tid' then
                            trace_tid = v
                        else
                            rawset(self, k, v)
                        end
                    end

                    function event_meta:__call(arg)
                        if arg == '*' then
                            return a1, a2, a3, a4
                        end
                    end
                end

                ------------------------ event loop ------------------------
                local function handle_trace(args)
                    local ok, r1, r2
                    if co_status(trace_routine) ~= 'dead' then
                        -- resume the trace routine
                        ok, r1, r2 = co_resume(trace_routine, args)
                        if not ok then
                            ui.error('[trace]', r1)
                            -- r1, r2 = ui.pause('TraceError~'..tid)
                        end
                    end
                    if not ok then
                        -- end the trace
                        trace_routine = nil
                        udbg.trace_routine = nil
                    end
                    return ok, r1, r2
                end

                local r1, r2 = 'run', false
                local event_args = udbg.event_args
                local traceable_event = udbg.traceable_event
                while true do
                    tid, eid, a1, a2, a3, a4 = continue_event(r1, r2)
                    -- log('[dbg]', e, a1, a2, a3, a4)
                    if not eid then break end

                    event_args.tid = tid
                    local trace_handled = false
                    if trace_routine and traceable_event[eid] then
                        -- not specify the trace_tid, or current is the trace_tid
                        if not trace_tid or trace_tid == tid then
                            local event_name = event_id[eid] or hex(eid)
                            ui.info('[trace]', event_name..'~'..tid, hex(reg._pc))
                            trace_handled, r1, r2 = handle_trace(event_args)
                        end
                    end
                    if not trace_handled then
                        local event_handler = handler_table[eid]
                        if event_handler then
                            -- local last_trace = trace_routine
                            -- handle the event
                            ok, r1, r2 = xpcall(event_handler, traceback, a1, a2, a3, a4)
                            if not ok then
                                ui.error('[debug]', r1)
                                local event_name = event_id[eid] or hex(eid)
                                r1, r2 = ui.pause(event_name..'~'..tid..': [error]')
                            end
                            -- begin trace
                            -- if trace_routine and trace_routine ~= last_trace then
                            --     ok, r1, r2 = handle_trace(event_args)
                            -- end
                        else
                            ui.error('[fatal]', 'unknown event', eid)
                            r1, r2 = ui.pause('UnknownEvent~'..tid..': '..hex(eid))
                        end
                    end
                end

                udbg.target = nil
                event.fire('target-end', target)
                udbg.set('target', nil)
            end)
            if not ok then
                ui.error('[fatal]', err)
                udbg.target = nil
            end
            __debug_thread = nil
        end)
    end
end