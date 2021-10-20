
local mod = {error = print, count = {}}

-- et[event_name] => handlers
-- et[event_func] => handlers
--      handlers => {event_func, ...}
---@type table<string|function,function[]>
local et = {}               -- event handler table

---@type table<function, integer>
local optTable = {__mode = 'k'}
setmetatable(optTable, optTable)

local xpcall, ipairs, type = xpcall, ipairs, type
local traceback = debug.traceback
local unpack = table.unpack
local resume, yield = coroutine.resume, coroutine.yield
local running = coroutine.running

---execute a function in another coroutine
---@param fn function
---@return boolean, ... @see coroutine.resume
local function async_call(fn, ...)
    local co = coroutine.create(fn)
    local ok, r1, r2, r3, r4, r5 = resume(co, ...)
    if not ok then
        r1 = traceback(co, r1)
    end
    return ok, r1, r2, r3, r4, r5
end

local count = mod.count
---fire a event
---@param event string
---@vararg any @arguments
function mod.fire(event, ...)
    local handlers = et[event]
    if not handlers then return end
    local ok, r1, r2, r3, r4, r5

    count[event] = (count[event] or 0) + 1
    for i, handler in ipairs {unpack(handlers)} do
        if type(handler) == "thread" then
            mod.cancel(handler)
            ok, r1, r2, r3, r4, r5 = resume(handler, ...)
            if not ok then r1 = traceback(handler, r1) end
        else
            ok, r1, r2, r3, r4, r5 = xpcall(handler, traceback, ...)
        end
        if not ok then
            mod.error('[event]', event, r1)
            r1 = nil
            -- break
        end
        if r1 ~= nil then break end
    end
    return r1, r2, r3, r4, r5
end

---get the last handler for event
---@param event string
---@param all boolean
---@return function|nil
function mod.get(event, all)
    local handlers = et[event]
    if handlers then
        if all == '*' then
            return handlers
        end
        return handlers[#handlers]
    end
end

local isyieldable = coroutine.isyieldable
local binary_search = table.binary_search

---register a event callback
---@param event string
---@param callback function
---@param opt? {order: integer, async: boolean}
---@return function @as a id, to cancel
local function on_event(self, event, callback, opt)
    if opt and opt.async then
        callback = coroutine.create(callback)
    end

    local ty = type(callback)
    if ty == "nil" then
        callback = running()
        ty = 'thread'
    end
    if ty == "function" then
        -- if exists, wrapper a function
        if et[callback] then
            callback = function(...) return callback(...) end
        end
    else
        assert(ty == "thread")
        assert(isyieldable(callback))
    end
    local handlers = et[event]
    local is_new = not handlers
    if is_new then handlers = {} end

    local pos, max = binary_search(handlers, opt and opt.order or 1, function(cur, o)
        local opt = optTable[cur]
        local curOrder = opt and opt.order or 1
        if curOrder == o then return 0 end
        return curOrder < o and -1 or 1
    end)
    optTable[callback] = opt

    table.insert(handlers, pos and pos + 1 or max or 1, callback)
    if is_new then et[event] = handlers end

    et[callback] = handlers
    -- registered function as id
    return callback
end

mod.on = {__call = on_event}
setmetatable(mod.on, mod.on)

local fire = mod.fire
function mod.on:__index(event)
    event = event:gsub('_', '-')
    return function(...)
        return fire(event, ...)
    end
end

function mod.on:__newindex(event, callback)
    event = event:gsub('_', '-')
    return on_event(self, event, callback)
end

mod.async_call = async_call

function mod.replace(event, callback)
    local handlers = et[event]
    if handlers then
        for _, fun in ipairs(handlers) do
            et[fun] = nil
        end
        et[event] = nil
    end
    return mod.on(event, callback)
end

---cancel a event callback
---@param id function|thread
---@return boolean
function mod.cancel(id)
    if not id then
        for i = 1, 10 do
            local info = debug.getinfo(i, 'f')
            if info and et[info.func] then
                id = info.func break
            end
        end
    end
    if not id then return end

    local handlers = et[id]; et[id] = nil
    -- lookup the handler and remove it
    for i, fun in ipairs(handlers) do
        if fun == id then
            table.remove(handlers, i)
            return true
        end
    end
end

function mod.cancel_all(event)
    local handlers = et[event]
    if handlers then
        et[event] = nil
        for _, fun in ipairs(handlers) do
            et[fun] = nil
        end
    end
end

return mod