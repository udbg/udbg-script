
local task = require 'udbg.task'

return function(args)
    local action = args[1]
    for _, t in ipairs(task.running) do
        log('[task]', t.start_time, t.name)
        if action == 'stop' then
            task.try_abort(t)
        end
        if action == 'wait' then
            t.thread:join()
        end
    end
end