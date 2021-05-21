
local t = {running = {}}

function t.spawn(callback, opt)
    assert(type(callback) == 'function')

    opt = opt or {}
    opt.name = opt.name or tostring(callback)

    if opt.interval then
        local origin = callback
        function callback(opt)
            local interval = opt.interval
            while not opt.abort do
                origin(opt)
                thread.sleep(interval)
            end
        end
    end

    opt.thread = thread.spawn(function()
        opt.coroutine = coroutine.running()
        local ok, err = xpcall(callback, debug.traceback, opt)
        if not ok then
            require 'udbg.ui'.error('[task]', opt.name, err)
        end
        opt.abort = true
        local i = table.find(t.running, opt)
        if i then table.remove(t.running, i) end
    end)
    opt.start_time = os.date '%c'
    table.insert(t.running, opt)
    return opt
end

function t.try_abort(opt)
    local try_abort = opt.try_abort
    if try_abort then
        try_abort()
    else
        opt.abort = true
    end
end

return t