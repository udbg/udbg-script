-- lua debugger helper for
-- * lua-debug(deprecated): https://github.com/actboy168/lua-debug
-- * LuaPanda: https://github.com/Tencent/LuaPanda/blob/master/Docs/Manual/access-guidelines.md

require 'udbg.lua'

local mod = {__mode = 'k'}

local cachedCoroutines = setmetatable({}, mod)

local panda
local luadebug
function mod.add(co)
    if type(co) == 'table' then
        table.foreachi(co, mod.add)
        return
    end

    assert(type(co == 'thread'))
    if luadebug then
        luadebug:event("thread", co, 0)
    end
    if panda then
        panda.changeCoroutineHookState(co, 3)
    end
    if not cachedCoroutines[co] then
        cachedCoroutines[co] = true
    end
end

function mod.check_load()
    if luadebug then return end
    luadebug = debug.getregistry()['lua-debug']
    if luadebug then
        print('lua-debug loaded')
        for co in pairs(cachedCoroutines) do
            print('add', co)
            luadebug:event("thread", co, 0)
        end
    end
end

function mod.init_luapanda(addr, port)
    if not panda then
        panda = require("LuaPanda")
        panda.start(addr, port)
        for co in pairs(cachedCoroutines) do
            print('changeCoroutineHookState', co)
            panda.changeCoroutineHookState(co, 3)
        end
    end
end

return mod