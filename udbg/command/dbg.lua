
local mod = {}

mod.parser = [[
dbg                                  -- start a debug session
    <target>     (string)               target pid/name

    -A, --adaptor (default '')          debug adaptor
    -p, --pid                           target as pid
    -a, --attach                        attach target
    -o, --open                          open target
    --spy                               use adaptor: spy
    --cwd (optional string)             set the work directory
]]

function mod.main(args)
    args.create = args.attach
    log(args)
    udbg.start(args)
end

return mod