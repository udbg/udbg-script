
local class = require 'class'
local ui = require 'udbg.ui'

local TABLE_GET = 1101
local TABLE_SET = 1102
local TABLE_APPEND = 1103
local TABLE_SET_TITLE = 1105
local TABLE_SCROLL = 1107
local AREA_SET_VSCROLL = 1108
local TABLE_SELECT_RANGE = 1109

local TABLE_CMD = 2001

local SCROLL<const> = 0
local RESIZE<const> = 1
local CLICK<const> = 2
local DB_CLICK<const> = 3
local SCROLLTO<const> = 4
local SELECTTO<const> = 5

---@class Table
---@field vid integer @view id in client
---@field viewHeight integer @view height in client (in lines)
local Table = class {
    __set = {},
    [SCROLL] = function(self, n)
        n = self:onScroll(n)
        if n then
            self:moveSelection(n)
            self:onUpdate()
            self:updateScrollBar()
        end
    end,
    [RESIZE] = function(self, height)
        -- log('stack height', height)
        self.viewHeight = height
        self:onUpdate()
        self:updateScrollBar()
    end,
    [CLICK] = function(self, i)
        self:onClick(i)
    end,
    [SCROLLTO] = function(self, i)
        if self:onScrollTo(i) then
            self:onUpdate()
            self:updateScrollBar()
        end
    end,
    [SELECTTO] = function(self, i)
        self:onSelectTo(i)
    end,
}

function Table:__init(vid)
    self.vid = vid
    self.viewHeight = 0
    self.pageStart = 0
    self.pageEnd = 0
    self.viewStart = 0
    self.scrollValue = 0
    self.selectStart = 0
    self.selectEnd = 0
    self.selectCur = 0
    self.itemSize = 1
end

function Table:isAlive()
    return true
end

function Table:setHeader(columns, showHeader)
    ui.notify(TABLE_CMD, {self.vid, TABLE_SET_TITLE, columns, showHeader})
end

function Table:setSelect(start, end_, cur)
    -- log('set', start or self.selectStart, end_ or self.selectEnd, cur or self.selectCur)
    ui.notify(TABLE_CMD, self.vid, TABLE_SELECT_RANGE, start or self.selectStart, end_ or self.selectEnd, cur or self.selectCur)
end

function Table:moveSelection(n)
    self.selectStart = self.selectStart - n
    self.selectEnd = self.selectEnd - n
    self.selectCur = self.selectCur - n
    self:setSelect(self.selectStart, self.selectEnd, self.selectCur)
end

function Table.__set:scrollBar(opt)
    -- log('scroll', opt)
    ui.notify(TABLE_CMD, self.vid, AREA_SET_VSCROLL, opt)
end

function Table:onClick(i)
    -- log('onClick', i)
    self.selectStart = i
    self.selectEnd = i
    self.selectCur = i
    self:setSelect()
end

-- scroll by wheel
function Table:onScroll(n)
    self:moveSelection(n)
end

-- slide the scroll bar
function Table:onScrollTo(i)
end

-- drag to select
function Table:onSelectTo(i)
    -- log('onSelectTo', i)
    i = math.max(i, -1)
    i = math.min(i, self.viewHeight)
    if i >= self.selectCur then
        self.selectStart = self.selectCur
        self.selectEnd = i
    elseif i < self.selectCur then
        self.selectEnd = self.selectCur
        self.selectStart = i
    end

    if i < 0 then
        self[SCROLL](self, i)
    elseif i >= self.viewHeight then
        self[SCROLL](self, i + 1 - self.viewHeight)
    else
        self:setSelect()
    end
end

function Table:onUpdate()
end

function Table:set(lines)
    ui.notify(TABLE_CMD, self.vid, TABLE_SET, lines)
end

function Table:update()
end

function Table:updateScrollBar(val)
    val = val or self.viewStart
    local pageStep = self.viewHeight
    self.scrollBar = {
        min = 0,
        max = (self.pageEnd - self.pageStart) // self.itemSize - pageStep,
        pageStep = pageStep,
        value = (val - self.pageStart) // self.itemSize,
    }
end

---@class StackView: Table
local StackView = class {
    __parent = Table,
    __get = {}, __set = {},
}

function StackView:__init(vid)
    Table.__init(self, vid)
    self._address = false
    self._stack = 0
    self:setHeader({
        {name = 'Address', width = 14},
        {name = 'Pointer', width = 18},
        {name = 'Extra', width = 80},
    }, false)
    StackView.__last_instance = self

    function self:isAlive()
        return udbg.target
    end
end

function StackView.__get:address()
    return self._address
end

function StackView.__set:address(val)
    self.itemSize = udbg.target.psize
    self:updatePage(assert(val))
    self._address = val
    self._stack = val
    self:onUpdate()
end

function StackView:updatePage(address)
    if address < self.pageStart or address >= self.pageEnd then
        local page = udbg.target:virtual_query(address)
        if page then
            self.pageStart = page.base
            self.pageEnd = page.base + page.size
            self.viewStart = address
            self:updateScrollBar()
        end
    end
end

function StackView:onScroll(n)
    local psize = self.itemSize
    local offset = n * psize
    local start = self.viewStart
    if n < 0 then
        self.viewStart = math.max(self.viewStart + offset, self.pageStart)
    else
        self.viewStart = math.min(self.viewStart + offset, self.pageEnd - psize * self.viewHeight)
    end
    return (self.viewStart - start) // psize
end

function StackView:onScrollTo(i)
    local psize = self.itemSize
    local start = self.viewStart
    self.viewStart = self.pageStart + psize * i
    self:moveSelection((self.viewStart - start) // psize)
    return true
end

function StackView:onUpdate()
    local val = self.viewStart
    local data = table {}
    local psize = self.itemSize
    for a = val, val + psize * self.viewHeight, psize do
        local p = read_ptr(a)
        if not p then break end
        local color, info, t = pointer_color_info(p, true)
        local addr, ptr = fmt_addr(a), fmt_size(p)
        local infocell = {text = info, fg = ui.color[color]}
        if t == 'return' then
            local sym = udbg.target:get_symbol(p) or ''
            info = info.string
            infocell.text = sym .. ' ; ' .. info
            infocell.format = {start = 0, length = #sym, fg = ui.color.blue}
        end
        if a < self._stack then
            addr = {text = addr, fg = ui.color.gray}
            ptr = {text = ptr, fg = ui.color.gray}
        end
        if a == self._stack then
            addr = {text = addr, fg = ui.color.white, bg = ui.color.black}
        end
        data:insert {addr, ptr, infocell}
    end
    if #data > 0 then
        self:set(data)
    end
end

local mod = {
    Table = Table,
    StackView = StackView,
}

return mod