
local mod = {}

mod.parser = [[
wait                         -- wait target and attach
    <filter> (string)           name filter

    -c, --cmdline               filter by cmdline
    -w, --window                filter by window name
]]

function mod.main(args)
    local filter = args.filter
    local attr = 'name'
    if args.cmdline then attr = 'cmdline' end
    if args.window then attr = 'window' end

    require 'udbg.task'.spawn(function(opt)
        for p in enum_psinfo() do
            if opt.abort then break end

            local a = p[attr]
            if a:find(filter) then
                log('[wait]', 'find', p.name)
                udbg.start {attach = p.pid}
                opt.abort = true break
            end
        end
    end, {name = 'wait: ' .. filter, interval = 100})
end

return mod