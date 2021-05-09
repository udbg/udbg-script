
local map = {
    kill = 'ui-kill-target',
    detach = 'ui-detach-target',
    restart = 'ui-restart-target',
}

return function(args)
    local action = args[1]
    action = map[action] or action
    require 'udbg.event'.fire(action)
end