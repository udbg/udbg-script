
local strchar = string.char
local tonumber = tonumber

function binary_pattern(pat)
    return pat:gsub('%s*%S+%s*', function(pat)
        pat = pat:trim()
        if pat:find('?', 1, true) then
            return '.'
        else
            local n = assert(tonumber('0x'..pat), 'Wrong Binary Pattern: ' .. pat)
            return strchar(n):escape()
        end
    end)
end

function search_binary(data, pat)
    local pattern = binary_pattern(pat)
    -- return function(data, i)
    --     local r = data:find(pattern, i + 2)
    --     if r then return r - 1 end
    -- end, data, -1
    local i = 1
    return function()
        local r = data:find(pattern, i)
        if r then
            i = r + 1
            return r - 1
        end
    end
end

function UDbgTarget:find_binary(opt)
    local a = assert(opt.address or opt[1])
    local pattern = assert(opt.pattern or opt[2])
    local size = opt.size or opt[3] or 0x1000

    local iter = search_binary(self:read_bytes(a, size), pattern)
    return function()
        local offset = iter()
        if offset then
            return a + offset
        end
    end
end

function UDbgTarget:search_memory(opt)
    local pattern = opt.pattern or opt[1]
    if opt.binary then
        opt.plain = false
        pattern = binary_pattern(pattern)
    end

    local start = opt.start and self:parse_address(opt.start)
    start = start or 0
    local stop = opt.stop and self:parse_address(opt.stop)
    stop = stop or 0x7FFFFFFFF
    if opt.module then
        local m = assert(self:get_module(opt.module), 'invalid module')
        start = m.base stop = m.base + m.size
    end
    -- log('start:', hex(start), 'stop:', hex(stop))

    return coroutine.wrap(function()
        local plain = opt.plain
        local yield = coroutine.yield
        for m in self:enum_memory() do
            local base, size = m.base, m.size
            -- if start then valid = valid and  end
            -- if stop then valid = valid and base + size < stop end
            if base >= start then
                local i = 1
                local buf = self:read_bytes(base, size)
                while buf do
                    if base + i - 1 >= stop then goto END end
                    i = buf:find(pattern, i, plain)
                    if i then
                        yield(base + i - 1)
                    else break end
                    i = i + 1
                end
            end
        end
        ::END:: return
    end)
end

function UDbgTarget:yara_search(opt)
    local rules = opt.rules or opt[1]
    local callback = assert(type(opt.callback) == 'function' and opt.callback)
    local progress = opt.progress

    local start = opt.start and self:parse_address(opt.start) or 0
    local stop = opt.stop and self:parse_address(opt.stop) or 0x7FFFFFFFFFFF
    assert(start < stop, 'start must less than stop')

    if opt.module then
        local m = assert(self:get_module(opt.module), 'invalid module')
        start = m.base; stop = m.base + m.size
    end
    -- log('start:', hex(start), 'stop:', hex(stop))

    local scanner, err, msg = require 'yara'.compile(rules)
    if not scanner then return err, msg end

    local max = opt.max
    local count = 0
    for m in self:enum_memory() do
        if opt.abort then break end
        if max and count > max then break end

        local la, ra = m.base, m.base + m.size
        if ra < start then goto continue end
        if la >= stop then goto continue end
        if start > la and start < ra then la = start end
        if stop > la and stop < ra then ra = stop end

        local buf = self:read_bytes(la, ra - la)
        if buf then
            local err, reason = scanner(buf, function(rule, offset, len)
                count = count + 1
                if max and count > max then return false end
                if false == callback(rule, la + (offset or 0), len or #buf) then
                    opt.abort = true
                    return false
                end
            end)
            if err then return err, reason end
        end
        if progress then
            progress((ra - start) / (stop - start))
        end
        ::continue::
    end
end
