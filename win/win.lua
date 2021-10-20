
local api = libffi.C
local libffi = require 'libffi'
local mod = {}

local cstring = libffi.string
local malloc = libffi.malloc

local WS_EX_TOPMOST = 8
local WS_EX_LAYERED = 0x00080000

function mod.enum_window(hwnd)
    hwnd = hwnd or api.GetTopWindow(0)
    local GW_HWNDNEXT = 2
    return function()
        if hwnd == 0 then return end
        hwnd = api.GetWindow(hwnd, GW_HWNDNEXT)
        if hwnd > 0 then return hwnd end
    end
end

function mod.enum_child(w, class)
    local child = 0
    class = class or 0
    return function()
        child = api.FindWindowExA(w, child, class, 0)
        if child == 0 then child = nil end
        return child
    end
    -- local GW_CHILD = 5
    -- local child = api.GetWindow(w, GW_CHILD)
    -- log('first child', child)
    -- return enumWindow(child)
end

function mod.get_class(hwnd)
    local buf = malloc(0x1000)
    local len = api.GetClassNameW(hwnd, buf, #buf//2)
    if len > 0 then
        return cstring(buf, len*2):from_utf16()
    end
end

-- local GetWindowTextW = api.GetWindowTextW
local GetWindowTextW = api.InternalGetWindowText
function mod.get_text(hwnd)
    local buf = malloc(0x1000)
    local len = GetWindowTextW(hwnd, buf, #buf//2)
    if len > 0 then
        return cstring(buf, len*2):from_utf16()
    end
end

function mod.is_visible(hwnd)
    return api.IsWindowVisible(hwnd) > 0
end

local SW = {
    HIDE            = 0,
    SHOWNORMAL      = 1,
    NORMAL          = 1,
    SHOWMINIMIZED   = 2,
    SHOWMAXIMIZED   = 3,
    MAXIMIZE        = 3,
    SHOWNOACTIVATE  = 4,
    SHOW            = 5,
    MINIMIZE        = 6,
    SHOWMINNOACTIVE = 7,
    SHOWNA          = 8,
    RESTORE         = 9,
    SHOWDEFAULT     = 10,
    FORCEMINIMIZE   = 11,
    MAX             = 11,
}
function mod.show_window(hwnd, what)
    return api.ShowWindow(hwnd, SW[what] or SW.SHOW) ~= 0
end

function mod.close(hwnd)
    local WM_QUIT = 0x0012
    local WM_CLOSE = 0x10
    api.SendMessageA(hwnd, WM_CLOSE, 0, 0)
    -- return api.CloseWindow(hwnd) > 0
end

function mod.destroy(hwnd)
    return api.DestroyWindow(hwnd) > 0
end

function mod.get_rect(hwnd)
    local buf = malloc(20)
    if api.GetWindowRect(hwnd, buf) > 0 then
        local rect = cstring(buf, 16)
        return ('i4i4i4i4'):unpack(rect)
    end
end

function mod.get_rgnbox(hwnd)
    local buf = malloc(20)
    if api.GetWindowRgnBox(hwnd, buf) > 0 then
        local rect = cstring(buf, 16)
        return ('i4i4i4i4'):unpack(rect)
    end
end

function mod.get_size(hwnd)
    local l, t, r, b = mod.get_rect(hwnd)
    if l then
        return r - l, b - t
    end
end

function mod.get_cursor_pos()
    local buf = malloc(8)
    if api.GetCursorPos(buf) > 0 then
        local rect = cstring(buf, 8)
        return ('i4i4'):unpack(rect)
    end
end

function mod.get_pid_tid(hwnd)
    local buf = malloc(4)
    local tid = api.GetWindowThreadProcessId(hwnd, buf)
    return buf 'I4', tid
end

local CF_TEXT<const> = 1
function mod.clipboard_text()
    if api.OpenClipboard(0) == 0 then
        error('OpenClipboard failed')
    end

    local result
    local ht = api.GetClipboardData(CF_TEXT)
    if ht ~= 0 then
        local p = api.GlobalLock(ht)
        if p ~= 0 then
            result = libffi.string(p)
        end
        api.GlobalUnlock(ht)
    end
    api.CloseClipboard()

    return result
end

return mod