
local libffi = require 'libffi'
local ui_callback = assert(libffi.load 'gui', 'gui not found').ui_callback

local F = libffi.fn('void', {'pointer'})

local QtCore, QtGui, QtWidgets
local running = coroutine.running

local guitid
local guistate
ui_callback(F(function()
    guitid = libffi.C.GetCurrentThreadId()
    QtCore = require 'qtcore'
    QtGui = require 'qtgui'
    QtWidgets = require 'qtwidgets'
    guistate = running()
    -- print('guistate', guistate)
    UDBG_QT_STAET = guistate
end))
while not guistate do thread.sleep(0) end

local mod = {QtCore = QtCore, QtGui = QtGui, QtWidgets = QtWidgets}
setmetatable(mod, {__index = function(self, key)
    local val = QtCore[key] or QtGui[key] or QtWidgets[key]
    if val then rawset(self, key, val) end
    return val
end})

function mod.gui(callback, wait, a1, a2, a3)
    local s = running()
    if s == guistate then
        return callback(a1, a2, a3)
    end
    local condvar = thread.condvar()
    local FFIClosure
    FFIClosure = F(function()
        local ok, err = xpcall(callback, debug.traceback, a1, a2, a3)
        wait = false
        condvar:notify_one()
        FFIClosure = nil
        assert(ok, err)
    end, guistate)
    ui_callback(FFIClosure, 0)
    wait = wait and condvar:wait()
end

function mod.inGui(callback, wait)
    return function()
        return mod.gui(callback, wait)
    end
end

function mod.qSetupUi(path, root, customBuilder)
    local QtCore = require 'qtcore'
    local QtWidgets = require 'qtwidgets'
    local QtUiTools = require 'qtuitools'

    local file = QtCore.QFile(path)
    file:open(QtCore.QIODevice.ReadOnly)

    local function createWidget(className, parent)
        local class = QtWidgets[className]
            -- or QtOpenGL[className]
            -- or QtQuickWidgets[className]
            -- or QtWebEngineWidgets[className]

        if class then
            return class.new(parent)
        end
        print('Unknown ui widget : ' .. tostring(className))
    end

    local loader = QtUiTools.QUiLoader()
    function loader:createWidget(className, parent, name)
        if not parent then
            return root
        end

        local widget = customBuilder and customBuilder(className, parent, name) or nil
        if widget == nil then
            -- try use lqt class.new to create widget
            --  you can use __addsignal/__addslot on created object
            widget = createWidget(className:toStdString(), parent)
        end
        -- set widget object name
        if widget ~= nil then
            widget:setObjectName(name)
            return widget
        end
        -- use default uitools widget creator
        return QtUiTools.QUiLoader.createWidget(self, className, parent, name)
    end

    local function traversalChildren(widget, callback)
        for name,child in pairs(widget:children()) do
            callback(name, child)
            traversalChildren(child, callback)
        end
    end

    local ui = {}

    local formWidget = loader:load(file)
    traversalChildren(formWidget, function(name, child)
        ui[name] = child
    end)

    root.ui = ui
    QtCore.QMetaObject.connectSlotsByName(root)

    return formWidget
end

function mod.SIGNAL(name) return '2' .. name end
function mod.SLOT(name) return '1' .. name end

mod.gui(function()
    setassociatedtid(guitid)
    pcall(require, 'qtuitools')

    require 'udbg.luadebug'.add(coroutine.running())

    local SlotObject = QtCore.Class('SlotObject', QtCore.QObject) {}
    local slotObject = UDBG_QT_SLOTOBJ or SlotObject()
    mod.slotObject = slotObject
    UDBG_QT_SLOTOBJ = slotObject

    local indexOfMethod = mod.QMetaObject.indexOfMethod
    local getProperty = mod.QMetaObject.property
    local getMethod = mod.QMetaObject.method
    local indexOfProperty = mod.QMetaObject.indexOfProperty
    local invoke2 = mod.QMetaMethod.invoke2

    function mod.metaGet(qobj, prop)
        local mo = qobj:metaObject()
        local i = indexOfProperty(mo, prop)
        if i >= 0 then
            return getProperty(mo, i):read(qobj)
        end
    end

    function mod.metaSet(qobj, prop, value)
        local mo = qobj:metaObject()
        local i = indexOfProperty(mo, prop)
        if i >= 0 then
            return getProperty(mo, i):write(qobj, QtCore.QVariant(value))
        end
    end

    function mod.getMetaCall(qobj, name)
        local mo = qobj:metaObject()
        local i = indexOfMethod(mo, name)
        if i < 0 then return end
        local method = getMethod(mo, i)
        return function(...)
            return invoke2(method, qobj, 0, ...)
        end 
    end

    function mod.metaCall(qobj, name, ...)
        local mo = qobj:metaObject()
        local i = indexOfMethod(mo, name)
        if i >= 0 then
            return invoke2(getMethod(mo, i), qobj, 0, ...)
        end
    end

    function mod.connect(w, signal, callback, slotname)
        slotname = slotname or signal:gsub('^%w+', function(name)
            return 'on_'..w:objectName():toStdString()..'_'..name..'_'..math.random(100, 999)
        end)
        -- print(slotname)
        slotObject:__addslot(slotname, callback)
        w:connect(mod.SIGNAL(signal), slotObject, '1'..slotname)
        return slotname
    end

    function mod.singleShotTimer(ms, callback)
        local slotname = 'onTimer_' .. os.time() .. '()'
        slotObject:__addslot(slotname, callback)
        QtCore.QTimer.singleShot(ms, slotObject, '1'..slotname)
    end

    function mod.action(opt)
        local action = QtWidgets.QAction.new()
        if opt.name then
            action:setObjectName(opt.name)
        end
        if opt.icon then
            local icon = QtGui.QIcon(opt.icon)
            action:setIcon(icon)
        end
        action:setText(opt.text or opt.name or '')
        if opt.on_trigger then
            action:connect('2triggered()', opt.on_trigger)
        end
        if opt.shortcut then
            action:setShortcut(QtGui.QKeySequence.fromString(opt.shortcut))
            action:setShortcutContext('WidgetShortcut')
            action:setShortcutVisibleInContextMenu(true)
        end
        return action
    end
end, true)

function mod.listIter(list)
    local i = -1
    local size = list:size()
    return function()
        i = i + 1
        if i < size then
            return i, list:at(i)
        end
    end
end

do  -- qt helper
    local Constructor = {}
    local empty = {}
    local helper = {Strech = {}}
    mod.helper = helper

    function Constructor.QTreeWidgetItem(opt)
        local strs = mod.QStringList()
        for i, val in ipairs(opt) do
            strs:append(tostring(val))
        end
        local res = mod.QTreeWidgetItem.new(strs)
        for _, child in ipairs(opt.childs or empty) do
            res:addChild(Constructor.QTreeWidgetItem(child))
        end
        return res
    end

    local AddChilds = {}

    function AddChilds:QVBoxLayout(childs)
        for _, widget in ipairs(childs) do
            if widget == helper.Strech then
                self:addStretch()
            elseif QtCore.isInstanceOf(widget, QtWidgets.QLayout) then
                self:addLayout(widget)
            else
                self:addWidget(widget)
            end
        end
    end
    AddChilds.QHBoxLayout = AddChilds.QVBoxLayout

    local function toWidget(widget)
        if QtCore.isInstanceOf(widget, QtWidgets.QLayout) then
            local w = QtWidgets.QWidget.new()
            w:setLayout(widget)
            w:setWindowTitle(widget.title or '')
            widget = w
        end
        return widget
    end

    function AddChilds:QTabWidget(childs)
        for _, widget in ipairs(childs) do
            widget = toWidget(widget)
            local windowTitle = widget.windowTitle
            local title = windowTitle and windowTitle(widget) or widget:objectName()
            self:addTab(widget, title)
        end
    end

    function AddChilds:QTreeWidget(opt)
        local columns = opt.columns
        if columns then
            self:setColumnCount(#columns)
            local header = self:headerItem()
            for i, col in ipairs(columns) do
                if type(col == 'table') then
                    if col.width then self:setColumnWidth(i-1, col.width) end
                    if col.name then header:setText(i-1, col.name) end
                else
                    header:setText(i-1, col)
                end
            end
        end

        function self:topLevelItems()
            local res = {}
            for i = 0, self:topLevelItemCount()-1 do
                table.insert(res, self:topLevelItem(i))
            end
            return res
        end
    end

    function AddChilds:QSplitter(opt)
        for _, widget in ipairs(opt) do
            self:addWidget(toWidget(widget))
        end
    end

    setmetatable(helper, {__index = function(self, className)
        local Widget = QtWidgets[className]
        if not Widget then return end

        return function(opt)
            local ctor = Constructor[className]
            local w = ctor and ctor(opt) or Widget.new()
            local isWindow = w.isWindow

            if isWindow and isWindow(w) then
                w:setAttribute('WA_DeleteOnClose')
            end

            -- set Properties
            for name, val in pairs(opt.__prop or empty) do
                mod.metaSet(w, name, val)
            end

            for name, val in pairs(opt.__luaprop or empty) do
                w[name] = val
            end

            for key, val in pairs(opt) do
                if type(key) == 'string' then
                    if key:find('%)$') and type(val) == 'function' then
                        -- connect signal to slot
                        w:connect('2'..key, val)
                    elseif not key:find '^__' then
                        -- call method
                        local fun = w[key]
                        if key == 'resize' then
                            local width, height = val.width or val[1] or 500, val.height or val[2] or 500
                            if width < 1 or height < 1 then
                                local rect = mod.QApplication.desktop():screenGeometry()
                                width = width < 1 and math.floor(width * rect:width()) or width
                                height = height < 1 and math.floor(height * rect:height()) or height
                                -- log(width, height)
                            end
                            local _ = fun and fun(w, width, height)
                        else
                            local _ = fun and fun(w, val)
                        end
                    end
                end
            end

            if opt.__init then opt.__init(w, opt) end

            local addChilds = AddChilds[className]
            if addChilds then
                addChilds(w, opt)
            end
            return w
        end
    end})
end

return mod