
local ui = require 'udbg.ui'
local event = require 'udbg.event'

---udbg.config is permanent config
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
    local bp_callback = {}   udbg.BPCallback = bp_callback
    local bp_extra_info = {} udbg.BpExtraInfo = bp_extra_info

    function on_breakpoint(tid, bp_id)
        local callback = bp_callback[bp_id]
        local pause = true
        if callback then pause = callback(tid, bp_id) end
        if pause then
            local r1, r2 = event.fire('targetBreakpoint', bp_id)
            if not r1 then
                r1, r2 = ui.pause('Breakpoint~'..tid..': '..hex(bp_id))
            end
            return r1, r2
        end
    end

    local pending_bp = {} _ENV.pending_bp = pending_bp

    event.on('targetModuleLoad', function()
        local to_remove = {}
        for symbol, opt in pairs(pending_bp) do
            if udbg.target:parse_address(symbol) then
                opt.auto = false
                log('[bp]', symbol, hex(udbg.target:add_bp(opt)))
                -- to remove
                table.insert(to_remove, symbol)
            end
        end
        -- remove the symbol be found
        for _ = 1, #to_remove, 1 do
            local key = table.remove(to_remove)
            pending_bp[key] = nil
        end
    end)

    function UDbgTarget:add_bp(a, opt, arg3)
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

        local address = self:eval_address(a)
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

        local bp, err = self:add_breakpoint(address, bp_type, bp_size, temp, tid)
        if err == 'exists' then
            bp = self:get_breakpoint(address)
            if bp then
                bp:remove()
            end
            bp, err = self:add_breakpoint(address, bp_type, bp_size, temp, tid)
        end

        if bp then
            local id = bp.id
            bp.enabled = enable
            bp_callback[id] = callback
        end
        return bp, err
    end

    local bp_remove = UDbgBreakpoint.remove
    function UDbgBreakpoint:remove()
        bp_callback[self.id] = nil
        return bp_remove(self)
    end

    function UDbgTarget:del_bp(id)
        local bp = self:get_breakpoint(id)
        return bp and bp:remove()
    end
end

do
    ---@type UDbgTarget
    local target
    event.on('targetSuccess', function()
        target = udbg.target
        ui.notify('onTargetSuccess', {
            pid = target.pid,
            psize = target.psize,
            os = os.name,
            arch = target.arch,
            name = target.name,
            path = target.path,
            os_psize = __llua_psize
        })
        local opt = event.fire 'beforeTargetSuccess'
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
        ui.info('[config]', __config)
    end, {order = 0})

    -- function event.on.targetEnded() target = nil end

    _G.reg = udbg.reg
    function _ENV:__index(k)
        local val
        local method = UDbgTarget[k]
        if type(method) == 'function' then
            val = function(...) return method(target, ...) end
        end
        if val then
            rawset(self, k, val)
        end
        return val
    end
    setmetatable(_ENV, _ENV)

    local function on_initbp(tid)
        local r1, r2 = event.fire 'targetInitBp'
        if __config.ignore_initbp then
            ui.warn('[ignore_initbp]', true)
        elseif not r1 then
            r1, r2 = ui.pause('InitBp~'..tid)
        end
        if __config.bp_process_entry then
            local m = target:get_module()
            if m then
                target:add_bp(m.entry_point, {temp = true})
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
        local reply, arg = event.fire('targetException', tid, code, first)
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
                    what, addr = target:eparam(0), target:eparam(1)
                    what = '[' .. (t[what] or hex(what)) .. ']'
                    addr = target:fmt_addr_sym(addr)
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

    local is_windows = os.name == 'windows'
    local function on_thread_create(tid)
        local t = target:open_thread(tid)
        event.fire('targetThreadCreate', t)
        local info = t and t.name or ''
        if is_windows then
            local teb = t and t.teb or 0
            if teb > 0 then info = info..' '..hex(t.teb) end
        end
        ui.info('[thread_create]', tid, info)
        if __config.pause_thread_create then
            return ui.pause('ThreadCreate')
        end
    end
    local function on_thread_exit(tid, code)
        event.fire('targetThreadExit', tid)
        ui.info('[thread_exit]', tid, code)
        if __config.pause_thread_exit then
            return ui.pause('ThreadExit')
        end
    end
    local function on_module_load(m)
        event.fire('targetModuleLoad', m)
        ui.info('[module_load]', hex(m.base), m.path)
        if __config.bp_module_entry then
            target:add_bp(m.entry_point, {temp = true})
        end
        if __config.pause_module_load then
            return ui.pause('ModuleLoad')
        end
    end
    local function on_module_unload(m)
        event.fire('targetModuleUnload', m)
        ui.info('[module_unload]', hex(m.base), m.name)
        if __config.pause_module_unload then
            return ui.pause('ModuleUnload')
        end
    end
    local function on_process_create(pid)
        event.fire('targetProcessCreate', pid)
        ui.info('[process_create]', pid)
        if __config.pause_process_create then
            return ui.pause('ProcessCreate')
        end
    end
    local function on_process_exit(pid, code)
        event.fire('targetProcessExit', pid, code)
        ui.info('[process_exit]', pid, code)
        if __config.pause_process_exit then
            return ui.pause('ProcessExit')
        end
    end

    local ev = udbg.Event
    udbg.event_handler = table {
        [ev.INIT_BP] = on_initbp,
        [ev.BREAKPOINT] = on_breakpoint,
        [ev.PROCESS_CREATE] = on_process_create,
        [ev.PROCESS_EXIT] = on_process_exit,
        [ev.THREAD_CREATE] = on_thread_create,
        [ev.THREAD_EXIT] = on_thread_exit,
        [ev.MODULE_LOAD] = on_module_load,
        [ev.MODULE_UNLOAD] = on_module_unload,
        [ev.EXCEPTION] = on_exception,
        [ev.STEP] = function(tid)
            local r1, r2 = event.fire('targetStep')
            if not r1 then
                r1, r2 = ui.pause('Step~'..tid)
            end
            return r1, r2
        end,
    }
    udbg.event_id = table {
        [ev.INIT_BP] = 'InitBp',
        [ev.BREAKPOINT] = 'Breakpoint',
        [ev.PROCESS_CREATE] = 'ProcessCreate',
        [ev.PROCESS_EXIT] = 'ProcessExit',
        [ev.THREAD_CREATE] = 'ThreadCreate',
        [ev.THREAD_EXIT] = 'ThreadExit',
        [ev.MODULE_LOAD] = 'ModuleLoad',
        [ev.MODULE_UNLOAD] = 'ModuleUnload',
        [ev.EXCEPTION] = 'Exception',
        [ev.STEP] = 'Step',
    }
    udbg.event_id:swap_key_value(true)

    local xpcall = xpcall
    local traceback = debug.traceback

    ---@class DebuggerOption
    ---@field adaptor string @debugger adaptor(engine)
    ---@field cwd string @current working directory
    ---@field target string|integer @target path or pid
    ---@field args string[] @shell arguments
    ---@field attach boolean @attach a active process
    ---@field open boolean @open a process, dont debug
    udbg.dbgopt = {}

    ---create udbg target
    ---@param opt DebuggerOption
    ---@return UDbgTarget
    function udbg.create(opt)
        local engine = opt.adaptor or 'default'
        if engine == '' then engine = 'default' end
        engine = assert(udbg.engine[engine], 'invalid debug engine: '..engine)

        local target = opt.target
        if opt.attach or opt.open then
            target = target or opt.attach or opt.open
            local pid = target
            if type(pid) ~= 'number' then
                pid = tonumber(pid)
                if not pid then
                    -- TODO: import auto_matcher
                    local match = auto_matcher(target)
                    -- find process by name
                    for ps in engine:enum_process() do
                        if match(ps.name) then
                            pid = ps.pid
                            break
                        end
                    end
                    assert(pid, 'process not found: '..target)
                end
            end
            return opt.attach and engine:attach(pid) or engine:open(pid)
        else
            return engine:create(assert(target, 'no target'), opt.cwd, opt.args or {})
        end
    end

    local debuggerMutex = thread.mutex()
    local debuggerThread
    ---start a debug session
    ---@param opt? DebuggerOption
    function udbg.start(opt)
        local guard = debuggerMutex:lock()
        if udbg.target then
            guard:unlock()
            error 'debugger thread exists'
        end
        -- if debuggerThread then
        --     debuggerThread:join()
        -- end

        opt = table.update(table.copy(udbg.dbgopt), opt or {})
        require 'udbg.task'.spawn(function(task)
            debuggerThread = task.thread
            task.finally = function() guard:unlock() end
            -- setassociatedtid(libffi.C.GetCurrentThreadId())

            local handler_table = udbg.event_handler
            local event_id = udbg.event_id
            local ok, continue_event

            do
                target = udbg.create(opt)
                continue_event = target:loop_event()
                udbg.target = target
                guard:unlock()
            end

            -- event data
            local tid, eid, a1, a2, a3, a4

            local base = target:base()
            debug.setuservalue(target, base, 1)
            target.psize = __llua_psize
            base.path = target.image_path
            udbg.set('target', target)

            event.fire('targetSuccess')

            function target.eventArgs(k)
                if k == '*' then
                    return a1, a2, a3, a4
                end
                if k == 1 then return a1 end
                if k == 2 then return a2 end
                if k == 3 then return a3 end
                if k == 4 then return a4 end
            end

            ------------------------ event loop ------------------------
            local r1, r2 = 'run', false
            while true do
                tid, eid, a1, a2, a3, a4 = continue_event(r1, r2)
                -- log('[dbg]', e, a1, a2, a3, a4)
                if not eid then break end

                target.event_tid = tid
                local event_handler = handler_table[eid]
                if event_handler then
                    ok, r1, r2 = xpcall(event_handler, traceback, a1, a2, a3, a4)
                    if not ok then
                        ui.error('[debug]', r1)
                        local event_name = event_id[eid] or hex(eid)
                        r1, r2 = ui.pause(event_name..'~'..tid..': [error]')
                    end
                else
                    ui.error('[fatal]', 'unknown event', eid)
                    r1, r2 = ui.pause('UnknownEvent~'..tid..': '..hex(eid))
                end
            end

            udbg.target = nil; udbg.set('target', nil)
            event.fire('targetEnded', target)

            debuggerThread = nil
            collectgarbage 'collect'
        end, {name = 'debugger'})
    end
end