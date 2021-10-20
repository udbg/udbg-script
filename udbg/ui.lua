
require 'udbg.lua'

local class = require 'class'
local unpack = table.unpack
local rawset = rawset
local xpcall, type = xpcall, type
local traceback = debug.traceback
local ucmd = require 'udbg.cmd'

local session = ui_session
if not session then return end
local notify, request = session.notify, session.request
local function ui_notify(method, ...) return notify(session, method, ...) end
local function ui_request(method, ...) return request(session, method, ...) end

local color = {
    [''] = 0, green = 1, blue = 2, gray = 3,
    yellow = 4, white = 5, black = 6, red = 7,
}

local TreeItem = {}
TreeItem.__index = TreeItem do
    local TREEITEM_GET_TEXT = 1200
    local TREEITEM_SET_TEXT = 1201
    local TREEITEM_CHILDS = 1202
    local TREEITEM_GET_ATTR = 1203
    local TREEITEM_SET_ATTR = 1204
    local TREEITEM_SET_CHILDS = 1205
    local TREEITEM_PARENT = 1206

    function TreeItem.from_id(id)
        if id > 0 then
            return setmetatable({id = id}, TreeItem)
        end
    end

    function TreeItem:set_text(i, text)
        ui_notify(TREEITEM_SET_TEXT, {self.id, i, text})
    end

    function TreeItem:get_text(i)
        return ui_request(TREEITEM_GET_TEXT, {self.id, i})
    end

    function TreeItem:childs()
        return table.imap(function(id)
            return TreeItem.from_id(id)
        end, ui_request(TREEITEM_CHILDS, {self.id}))
    end

    function TreeItem:parent()
        local id = ui_request(TREEITEM_PARENT, {self.id})
        return id and TreeItem.from_id(id)
    end

    function TreeItem:show_child(b)
        ui_notify(TREEITEM_SET_ATTR, {self.id, 'child', b})
    end

    function TreeItem:set_bg(i, color)
        ui_notify(TREEITEM_SET_ATTR, {self.id, 'bg', i, color})
    end

    function TreeItem:get_attrs(...)
        return unpack(ui_request(TREEITEM_GET_ATTR, {self.id, ...}))
    end

    function TreeItem:set_childs(childs)
        ui_notify(TREEITEM_SET_CHILDS, {self.id, childs})
    end
end

local ui = {
    notify = ui_notify, request = ui_request,
    session = session, color = color,
    TreeItem = TreeItem,

    -- Qt::Orientation
    Orientation = class.enum {
        Horizontal = 0x1,
        Vertical = 0x2,
    },
    -- Qt::WindowState
    WindowState = class.bits {
        WindowNoState    = 0x00000000,
        WindowMinimized  = 0x00000001,
        WindowMaximized  = 0x00000002,
        WindowFullScreen = 0x00000004,
        WindowActive     = 0x00000008
    },
}

do
    -- Qt::WindowType
    local Window = 1
    local Sheet = 0x00000004 | Window
    local Dialog = 0x00000002 | Window
    local Popup = 0x00000008 | Window
    local ToolTip = Popup | Sheet
    local WindowMinimizeButtonHint = 0x00004000
    local WindowMaximizeButtonHint = 0x00008000

    ui.WindowType = {
        Widget = 0x00000000,
        Window = 0x00000001,
        Dialog = Dialog,
        Sheet = 0x00000004 | Window,
        Drawer = Sheet | Dialog,
        Popup = Popup,
        Tool = Popup | Dialog,
        ToolTip = ToolTip,
        SplashScreen = ToolTip | Dialog,
        Desktop = 0x00000010 | Window,
        SubWindow = 0x00000012,
        ForeignWindow = 0x00000020 | Window,
        CoverWindow = 0x00000040 | Window,

        WindowType_Mask = 0x000000ff,
        MSWindowsFixedSizeDialogHint = 0x00000100,
        MSWindowsOwnDC = 0x00000200,
        BypassWindowManagerHint = 0x00000400,
        -- X11BypassWindowManagerHint = BypassWindowManagerHint,
        FramelessWindowHint = 0x00000800,
        WindowTitleHint = 0x00001000,
        WindowSystemMenuHint = 0x00002000,

        WindowMinimizeButtonHint = WindowMinimizeButtonHint,
        WindowMaximizeButtonHint = WindowMaximizeButtonHint,
        WindowMinMaxButtonsHint = WindowMinimizeButtonHint | WindowMaximizeButtonHint,
        WindowContextHelpButtonHint = 0x00010000,
        WindowShadeButtonHint = 0x00020000,
        WindowStaysOnTopHint = 0x00040000,
        WindowTransparentForInput = 0x00080000,
        WindowOverridesSystemGestures = 0x00100000,
        WindowDoesNotAcceptFocus = 0x00200000,
        MaximizeUsingFullscreenGeometryHint = 0x00400000,

        CustomizeWindowHint = 0x02000000,
        WindowStaysOnBottomHint = 0x04000000,
        WindowCloseButtonHint = 0x08000000,
        MacWindowToolBarButtonHint = 0x10000000,
        BypassGraphicsProxyWidget = 0x20000000,
        NoDropShadowWindowHint = 0x40000000,
        WindowFullscreenButtonHint = 0x80000000
    }

    -- QSizePolicy::PolicyFlag
    local PolicyFlag = class.bits {
        GrowFlag = 1,
        ExpandFlag = 2,
        ShrinkFlag = 4,
        IgnoreFlag = 8
    }
    ui.PolicyFlag = PolicyFlag

    -- QSizePolicy::Policy
    ui.SizePolicy = {
        Fixed = 0,
        Minimum = PolicyFlag.GrowFlag,
        Maximum = PolicyFlag.ShrinkFlag,
        Preferred = PolicyFlag.GrowFlag | PolicyFlag.ShrinkFlag,
        MinimumExpanding = PolicyFlag.GrowFlag | PolicyFlag.ExpandFlag,
        Expanding = PolicyFlag.GrowFlag | PolicyFlag.ShrinkFlag | PolicyFlag.ExpandFlag,
        Ignored = PolicyFlag.ShrinkFlag | PolicyFlag.GrowFlag | PolicyFlag.IgnoreFlag
    }
end

do      -- ui utils
    local tostring = tostring

    function ui.save_path(opt)
        opt = opt or {}
        opt.type = 'file'
        opt.title = opt.title or 'Save File'
        opt.path = opt[1] or opt.path
        return ui.input(opt)
    end

    local INFO<const> = 3
    local LOG<const> = 4
    local WARN<const> = 5
    local ERROR<const> = 6
    local LOG_COLOR<const> = 28
    local concat = string.concat

    if _G.log then
        ui.log, ui.info, ui.warn, ui.error = log.log, log.info, log.warn, log.error
        ui.logc = log.color
    else
        function ui.info(...) ui_notify(INFO, concat(...)) end
        function ui.log(...) ui_notify(LOG, concat(...)) end
        function ui.warn(...) ui_notify(WARN, concat(...)) end
        function ui.error(...) ui_notify(ERROR, concat(...)) end

        local log = {}
        _G.log = log
        setmetatable(log, log)

        function ui.logc(c, t, width)
            ui_notify(LOG_COLOR, {color[c] or c, tostring(t), width})
        end

        function log:__call(...)
            return ui_notify(INFO, concat(...))
        end

        function log.color_line(line)
            ui_notify(LOG_COLOR, line)
        end

        log.log, log.warn, log.info, log.error = ui.log, ui.warn, ui.info, ui.error
        log.color = ui.logc
        log.colormap = color
    end
    function ui.clog(args)
        local sep = args.sep or ' '
        local line = args.line or '\n'
        local a = {table.unpack(args)}
        local c = #a
        for i = 1, c, 2 do
            a[i] = assert(color[a[i]], 'invalid color')
            a[i+1] = a[i+1] .. sep
        end
        if #line > 0 then
            a[c+1] = color.white
            a[c+2] = line
        end
        ui_notify(LOG_COLOR, a)
    end
end

---@class CtrlOpt
---@field name string
---@field title string
---@field width number
---@field height number
---@field layout string|"'vbox'"|"'hbox'"
---@field class string
---@field on_destroy fun(self:Object)
---@field on_toggle fun(self:Object, state:boolean)
---@field on_click fun(self:Object)

---@class Object: CtrlOpt
---@field private _ctrl_id integer @id on remote
---@field private _data_id integer @id on local
---@field private _root Object
---@field childs Object[]
local Object = class {__get = {}} do
    ui.Object = Object
    local weak_value = {__mode = 'v'}
    ---@type table<integer, Object>
    local data_map = {}     -- data_id -> ctrl_data
    setmetatable(data_map, weak_value)

    ---@type table<integer, Object>
    local qobj_map = {}     -- qobj_id -> ctrl_data
    -- setmetatable(qobj_map, qobj_map)

    local OBJECT_METADATA<const> = 1600
    local WIDGET_SET_CALLBACK<const> = 1709
    local WIDGET_FIND_CHILD<const> = 1711
    local OBJECT_INVOKE<const> = 1712
    local OBJECT_GET_PROPERTY<const> = 1713
    local OBJECT_SET_PROPERTY<const> = 1714

    ui.OBJECT_INVOKE = OBJECT_INVOKE
    ui.OBJECT_GET_PROPERTY = OBJECT_GET_PROPERTY
    ui.OBJECT_SET_PROPERTY = OBJECT_SET_PROPERTY

    local ADD_MENU = 1800
    local ADD_ACTION = 1801

    local function check_size(opt, key)
        local size = rawget(opt, key)
        if size then
            if type(size) == 'number' then
                size = {size, size}
            else
                size[1] = size.width or size[1] or 300
                size[2] = size.height or size[2] or 300
            end
        end
        opt[key] = size
        return size
    end

    local specialObject = {}
    -- register a control class
    ---@param opt table
    ---@param clazz string | "'label'"|"'spin'"|"'button'"|"'radio'"|"'text'"|"'menu'"|"'action'"
    ---@return Object
    local function register_ctrl(opt, clazz)
        if type(opt) == 'string' then
            opt = {title = opt}
        end
        clazz = clazz or opt._class or 'Object'
        opt.class = clazz
        local data_id = topointer(opt)
        check_size(opt, 'size')
        check_size(opt, 'minsize')
        check_size(opt, 'maxsize')
        opt._data_id = data_id
        data_map[data_id] = opt
        local ctrl_id = opt._ctrl_id
        local result = ctrl_id and qobj_map[ctrl_id] or setmetatable(opt, specialObject[clazz] or Object)
        if ctrl_id then
            qobj_map[ctrl_id] = result
        end
        return result
    end

    local function set_childs(opt)
        if not opt.childs then
            local childs = table {unpack(opt)}
            for i = #opt, 1, -1 do
                table.remove(opt, i)
            end
            opt.childs = childs
        end
    end

    local function handle_root(root, data2ctrl)
        if not root.childs then
            root.childs = {}
        end
        for i = 1, #data2ctrl, 3 do
            local data_id, ctrl_id = data2ctrl[i], data2ctrl[i+1]
            -- log(data_id, '->', ctrl_id)
            local data = data_map[data_id]
            if data then
                data._ctrl_id = ctrl_id
                rawset(data, 'value', nil)
                rawset(data, 'title', nil)
                rawset(data, '_root', root)
                local _class = data2ctrl[i+2]
                rawset(data, '_class', _class)

                qobj_map[ctrl_id] = data
                if data.name then
                    root.childs[data.name] = data
                end
            end
        end
    end

    local classInfo = {}

    local function handle_class_info(info)
        local methodIndex, propIndex = {}, {}
        for i, method in ipairs(info.methods) do
            method.index = i - 1
            methodIndex[method.name] = i - 1
            info.methods[method.name] = method
        end
        for i, prop in ipairs(info.properties) do
            prop.index = i - 1
            propIndex[prop.name] = i - 1
            info.properties[prop.name] = prop
        end
        info.propIndex = propIndex
        info.methodIndex = methodIndex
        return info
    end

    function Object.__get:_meta()
        local info = rawget(classInfo, self._class)
        if not info then
            info = ui_request(OBJECT_METADATA, self._ctrl_id)
            if info then
                classInfo[self._class] = handle_class_info(info)
            end
        end
        rawset(self, '_meta', info)
        return info
    end

    local function WidgetSet(self, key, val)
        if key:find '^on_' then
            ui_notify(WIDGET_SET_CALLBACK, {self._ctrl_id, {[key] = true}})
        end
        rawset(self, key, val)
    end

    local function WidgetInvoke(self, method, ...)
        ui_notify(OBJECT_INVOKE, {self._ctrl_id, method or '', ...})
        return self
    end
    Object.__call = WidgetInvoke
    Object.invoke = WidgetInvoke

    function Object:__init(opt)
        if type(opt) == 'string' then
            self._ctrl_id = opt
        else
            table.update(self, opt)
        end
    end

    function Object:call(method, ...)
        return ui_request(OBJECT_INVOKE, {self._ctrl_id, method or '', ...})
    end

    Object.__newindex = WidgetSet

    ---get OObject's property
    ---@param prop string
    ---@return any
    function Object:get(prop)
        return ui_request(OBJECT_GET_PROPERTY, {self._ctrl_id, prop or ''})
    end

    ---set OObject's property, return self
    ---@param prop string
    ---@param value any
    ---@return Object
    function Object:set(prop, value)
        ui_notify(OBJECT_SET_PROPERTY, {self._ctrl_id, prop or '', value, false})
        return self
    end

    function Object:on(signal, callback)
        if not rawget(self, signal) then
            ui_notify(WIDGET_SET_CALLBACK, {self._ctrl_id, {[signal] = true}})
            rawset(self, signal, callback)
        end
        return self
    end

    ---find child in local cache
    ---@param name string
    ---@return Object?
    function Object:find(name)
        return self._root.childs[name]
    end

    ---find child object by QObject::findChild
    ---@param name string
    ---@return Object?
    function Object:find_child(name)
        local id = ui_request(WIDGET_FIND_CHILD, {self._ctrl_id, name or ''})
        local res = table {}
        if type(id) == 'table' then
            for i = 1, #id, 2 do
                if id[i] then
                    res:insert(register_ctrl({_ctrl_id = id[i], _class = id[i+1]}))
                else
                    res:insert(false)
                end
            end
            return res:unpack()
        end
    end

    ---start a timer
    ---@param interval integer @in milliseconds
    ---@return integer @timer id
    function Object:start_timer(interval)
        return self:call('startTimer', interval or 1000)
    end

    ---kill a timer
    ---@param id integer @timer id
    function Object:kill_timer(id)
        self('killTimer', id or 0)
        return self
    end

    function Object:add_action(opt, default)
        if type(opt) == 'string' and opt:find('---', 1, true) then
            opt = opt
        else
            opt = ui.action(opt)
        end
        local ctrl_id = ui_request(ADD_ACTION, {self._ctrl_id, opt, default})
        if type(ctrl_id) == 'number' then
            opt._ctrl_id = ctrl_id
            qobj_map[ctrl_id] = opt
            if self._root then
                handle_root(self._root, {opt._data_id, ctrl_id, 'QAction'})
            end
        end
        return opt
    end

    function Object:context_actions(actions)
        assert(type(actions) == 'table' and actions[1])
        ui_notify(ADD_ACTION, {self._ctrl_id, actions})

        local cb = {}
        for _, item in ipairs(actions) do
            if item.name then
                cb[item.name] = item.on_trigger
            end
        end
        function self:on_contextAction(name)
            local callback = cb[name]
            return callback and callback(self, name)
        end
    end

    local QMenu = class {__parent = Object}
    specialObject.QMenu = QMenu
    specialObject.menu = QMenu

    function QMenu:add_menu(opt)
        local data2ctrl = ui_request(ADD_MENU, {self._ctrl_id, ui.menu(opt)})
        handle_root(self, data2ctrl)
        return opt
    end

    local TABLE_GET = 1101
    local TABLE_SET = 1102
    local TABLE_APPEND = 1103
    ui.APPEND = 1103
    local TABLE_SET_COLOR = 1106
    ui.SET_COLOR = 1106

    local CommonTable = class {__parent = Object}
    specialObject.table = CommonTable
    specialObject.CommonTable = CommonTable

    ---get specific line data
    ---@param l integer|"'.'" @line number, '.' means the selected line
    ---@param c integer @column number, -1 means the last column
    ---@return string|nil
    function CommonTable:line(l, c)
        return ui_request(OBJECT_INVOKE, {self._ctrl_id, TABLE_GET, l or '.', c or -1})
    end

    function CommonTable:set_line(l, c, data)
        ui_notify(OBJECT_INVOKE, {self._ctrl_id, TABLE_SET, assert(l), c, data})
    end

    ---append line
    ---@param line string[]
    function CommonTable:append(line)
        ui_notify(OBJECT_INVOKE, {self._ctrl_id, TABLE_APPEND, assert(line)})
    end

    function CommonTable:set_color(l, c, fg)
        assert(l and c and fg)
        ui_notify(OBJECT_INVOKE, {self._ctrl_id, TABLE_SET_COLOR, l, c, color[fg] or 0})
    end

    ---create a QLabel
    ---@param opt CtrlOpt
    ---@return Object
    function ui.label(opt)
        return register_ctrl(opt, 'label')
    end

    ---create a QPushButton
    ---@param opt CtrlOpt
    ---@return Object
    function ui.button(opt)
        return register_ctrl(opt, 'button')
    end

    ---create a QProgressBar
    ---@param opt CtrlOpt
    ---@return Object
    function ui.progress(opt)
        return register_ctrl(opt, 'progress')
    end

    ---create a QRadioButton
    ---@param opt CtrlOpt
    ---@return Object
    function ui.radio(opt)
        return register_ctrl(opt, 'radio')
    end

    ---create a QCheckBox
    ---@param opt CtrlOpt
    ---@return Object
    function ui.checkbox(opt)
        return register_ctrl(opt, 'checkbox')
    end

    ---create a QComboBox
    ---@param opt CtrlOpt
    ---@return Object
    function ui.combobox(opt)
        return register_ctrl(opt, 'combobox')
    end

    ---create a QLineEdit
    ---@param opt CtrlOpt
    ---@return Object
    function ui.linetext(opt)
        return register_ctrl(opt, 'text')
    end

    ---create a QTextEdit
    ---@param opt CtrlOpt
    ---@return Object
    function ui.textedit(opt)
        return register_ctrl(opt, 'textedit')
    end

    ---create a QDoubleSpinBox/QSpinBox
    ---@param opt CtrlOpt
    ---@return Object
    function ui.spin(opt)
        return register_ctrl(opt, 'spin')
    end

    ---create a QGroupBox
    ---@param opt CtrlOpt
    ---@return Object
    function ui.groupbox(opt)
        set_childs(opt)
        return register_ctrl(opt, 'groupbox')
    end

    ---create a QDialogButtonBox
    ---@param opt CtrlOpt
    ---@return Object
    function ui.buttonbox(opt)
        set_childs(opt)
        return register_ctrl(opt, 'buttonbox')
    end

    function ui.splitter(opt)
        set_childs(opt)
        return register_ctrl(opt, 'split')
    end

    ---create a CommonTable
    ---@param opt CtrlOpt
    ---@return Object
    function ui.table(opt)
        return register_ctrl(opt, 'table')
    end

    function ui.tree(opt)
        return register_ctrl(opt, 'tree')
    end

    ---create a QVBoxLayout
    ---@param opt CtrlOpt
    ---@return Object
    function ui.vbox(opt)
        set_childs(opt)
        return register_ctrl(opt, 'vbox')
    end

    ---create a QHBoxLayout
    ---@param opt CtrlOpt
    ---@return Object
    function ui.hbox(opt)
        set_childs(opt)
        return register_ctrl(opt, 'hbox')
    end

    ---create a QGridLayout
    ---@param opt CtrlOpt
    ---@return Object
    function ui.grid(opt)
        set_childs(opt)
        return register_ctrl(opt, 'grid')
    end

    ---create a QFormLayout
    ---@param opt CtrlOpt
    ---@return Object
    function ui.form(opt)
        set_childs(opt)
        return register_ctrl(opt, 'form')
    end

    function ui.tabs(opt)
        set_childs(opt)
        return register_ctrl(opt, 'tabs')
    end

    function ui.editor(opt)
        return register_ctrl(opt, 'editor')
    end

    local NEW_DIALOG = 1500
    local NEW_DOCK = 1501
    local INPUT_DIALOG = 1502
    local GET_CLIPBOARD = 1503

    ---create a QDialog
    ---@param opt CtrlOpt
    ---@return Object
    function ui.dialog(opt)
        opt.layout = opt.layout or 'vbox'
        set_childs(opt)
        register_ctrl(opt, 'dialog')
        -- log('[dialog]', opt)
        handle_root(opt, ui_request(NEW_DIALOG, opt))
        return opt
    end

    -- get text in clipboard
    ---@return string
    function ui.clipboard()
        return ui_request(GET_CLIPBOARD, false)
    end

    function ui.dock(opt)
        opt.layout = opt.layout or 'vbox'
        set_childs(opt)
        register_ctrl(opt, 'dock')
        handle_root(opt, ui_request(NEW_DOCK, opt))
        return opt
    end

    -- input some value from gui
    ---@param opt table
    --- 'type': 'file' | 'double' | 'int' | 'text'
    --- 'title' string
    ---@return any
    function ui.input(opt)
        if type(opt) == 'string' then
            opt = {label = opt}
        end
        return ui_request(INPUT_DIALOG, opt or {type = 'text'})
    end

    function ui.menu(opt)
        set_childs(opt)
        if opt.before then
            opt.before = opt.before._ctrl_id
        end
        return register_ctrl(opt, 'menu')
    end

    function ui.action(opt)
        return register_ctrl(opt, 'action')
    end

    function ui.on_ctrl_event(ctrl_id, event, a1, a2, a3)
        local data = qobj_map[ctrl_id]
        -- print('[on_ctrl_event]', ctrl_id, event)
        if not data then
            -- ui.warn('[ctrl]', hex(ctrl_id), 'not found')
            return
        end

        if event == 'on_destroy' then
            -- ui.info('on_destroy', data)
            qobj_map[data._ctrl_id] = nil
        end

        local handler = data[event]
        if handler then
            local ok, err = xpcall(handler, traceback, data, a1, a2, a3)
            if not ok then
                ui.error((data.class or '')..'.'..event..'@'..(data.name or hex(ctrl_id)), err)
            end
        else
            -- ui.warn((data.class or '')..'.'..event..'@'..(data.name or hex(ctrl_id)), 'not found')
        end
    end

    ui.main = register_ctrl {_ctrl_id = 1, _class = 'UDbgWindow', add_menu = QMenu.add_menu}
end

do      -- io utils
    local MAKE_DIR<const> = 9
    local OPEN_FILE<const> = 30
    local READ_FILE<const> = 31
    local WRITE_FILE<const> = 32
    local CLOSE_FILE<const> = 33

    local READ_THE_FILE<const> = 1003

    local File = {}
    File.__index = File

    function File:read(size)
        return ui_request(READ_FILE, {self.__id, size})
    end

    function File:write(data)
        return ui_notify(WRITE_FILE, {self.__id, data})
    end

    function File:close()
        if self.__id then
            ui_notify(CLOSE_FILE, self.__id)
            self.__id = nil
        end
    end
    File.__gc = File.close
    File.__close = File.close

    -- make a directory
    ---@param dir string
    ---@return boolean
    function ui.make_dir(dir)
        return ui_request(MAKE_DIR, dir)
    end

    -- read file content
    ---@param path string
    ---@return string
    function ui.readfile(path)
        path = path:gsub('$data', __data_dir or '')
        return ui_request(READ_THE_FILE, path)
    end

    function ui.writefile(path, data)
        local f<close> = ui.openfile(path, true)
        local size = 0x4000
        local i = 0
        while true do
            local item = data:sub(i + 1, i + size)
            if #item == 0 then break end
            f:write(item)
            i = i + size
        end
    end

    function ui.writefile_once(path, data)
        local WRITE_FILE = 1001
        return ui_request(WRITE_FILE, {path, data})
    end

    function ui.openfile(path, write)
        return setmetatable({__id = ui_request(OPEN_FILE, {path, write or false})}, File)
    end
end

local json = require 'cjson'
local event = require 'udbg.event'

local thread = thread
local cond = thread.condvar()

function ui.pause(reason)
    -- TODO: console mode
    ui.g_status:set('text', reason or 'Paused')
    ui.stack.address = reg._sp
    ui.view_regs('setRegs', udbg.target:register())
    ui.view_disasm:set('pc', reg._pc)
    ui.goto_cpu(reg._pc)
    ui.main 'alertWindow'
    local r = cond:wait()
    ui.view_disasm:set('pc', 0)
    ui.g_status:set('text', 'Running')

    return table.unpack(r)
end

function ui.continue(a, b)
    cond:notify_one {a, b}
end

function ui.goto_cpu(a)
    ui.view_disasm:set('address', type(a) == 'string' and eval_address(a) or a)
    ui.Object 'dockCpu' 'raise'
    ui.view_disasm 'setFocus'
end

function ui.goto_mem(a)
    ui.view_mem:set('address', type(a) == 'string' and eval_address(a) or a)
    ui.Object 'dockMemory' 'raise'
    ui.view_mem 'setFocus'
end

function ui.goto_page(a)
    a = type(a) == 'string' and eval_address(a) or a
    local data = ui.update_memory_layout()
    if data then
        local i = table.binary_search(data, a, function(m, a)
            if a < m.base then return 1 end
            if a >= m.base + m.size then return -1 end
            return 0
        end)
        if i then
            ui.memoryLayout:set('scrollTo', i - 1)
            ui.Object 'dockMemoryLayout' 'raise'
        end
    end
end

local units = {"K", "M", "G", "T"}
function ui.humanSize(size)
    local i = 0
    while size > 1024 do
        size = size / 1024
        i = i + 1
    end
    local unit = units[i]
    return unit and ('%.1f %s'):format(size, unit) or tostring(size)
end

function ui.update_memory_layout()
    if not udbg.target then return end
    local data = table {}
    local format = string.format
    for _, m in ipairs(get_memory_map()) do
        local usage = m.usage
        if usage == 'PEB' then
            usage = {text = usage, fg = 'darkRed'}
        elseif usage:startswith 'Stack' then
            usage = {text = usage, fg = 'darkGreen'}
        elseif usage:startswith 'Heap' then
            usage = {text = usage, fg = 'darkMagenta'}
        end
        local size = m.size
        size = format('%x (%s)', size, ui.humanSize(size))
        local item = {fmt_addr(m.base), size, m.type, m.protect, usage}
        item.base = m.base
        item.size = m.size
        data:insert(item)
    end
    ui.memoryLayout:set('data', data)
    return data
end

function ui.update_handle_list()
    local target = udbg.target
    if not target then return end
    local data = table {}
    local format = string.format
    for handle, type_index, type_name, name in target:enum_handle() do
        data:insert {type_name, type_index, format('%x', handle), name}
    end
    ui.view_handle:set('data', data)
    return data
end

function ui.update_module_list()
    local target = udbg.target
    -- stateconfig('exception', false)
    if not target then return end
    local data = table {}
    for m in target:enum_module() do
        data:insert {m.name, fmt_addr(m.base), hex(m.size), fmt_addr(m.base + m.entry), m.arch, m.path, m'pdb_path'}
    end
    ui.view_module:set('data', data)
end

local last_bplist = {}
function ui.update_bp_list()
    local target = udbg.target
    if not target then return end
    last_bplist = target:breakpoint_list()
    local data = table {}
    for i, bp in ipairs(last_bplist) do
        data:insert {target:fmt_addr_sym(bp.address), bp.type, bp.enabled, bp.hitcount}
    end
    ui.Object 'bplist':set('data', data)
end

local windows = os.name == 'windows'
function ui.update_thread_list()
    local target = udbg.target
    if not target then return end
    local data = table {}
    for tid, t in pairs(target:thread_list()) do
        if windows then
            local entry = t.entry
            local ok, suspend_count = pcall(t.suspend, t)
            local pc = t('reg', '_pc') or 0
            data:insert {
                tid, target:fmt_addr_sym(entry), fmt_addr(t.teb or 0),
                target:fmt_addr_sym(pc), t.status, t.priority, ok and suspend_count or -1,
                hex(t:last_error(target)), t.name,
            }
            if ok then t:resume() end
        else
        end
    end
    table.sort(data, function(a, b) return a[1] < b[1] end)
    ui.view_thread:set('data', data)
end

local update_thread
local to_update = {}
local updater = {
    module = ui.update_module_list,
    bplist = ui.update_bp_list,
    thread = ui.update_thread_list,
    handle = ui.update_handle_list,
    memoryLayout = ui.update_memory_layout,
}
function ui.update_view(what)
    if update_thread then
        to_update[what] = true
        return
    end
    if not udbg.target then
        return
    end
    update_thread = require'udbg.task'.spawn(function()
        while udbg.target do
            for key, value in pairs(to_update) do
                local fun = updater[key]
                if fun then
                    local ok, err = xpcall(fun, debug.traceback)
                    if not ok then
                        ui.error('[update %s]' % key, err)
                    end
                end
            end
            to_update = {}
            thread.sleep(10)
        end
        update_thread = false
    end, {name = 'view-update'})
    return ui.update_view(what)
end

function ui.stop_target()
    if udbg.target then
        udbg.target:kill()
    end
    if udbg.target then
        ui.continue 'run'
    end
end

function ui.detach_target()
    if udbg.target then
        udbg.target:detach()
        ui.continue 'run'
    end
end

function ui.restart_target()
    ui.stop_target()
    require'udbg.task'.spawn(function()
        for _ = 1, 200 do
            if not udbg.target then break end
            thread.sleep(10)
        end
        if udbg.target then
            ui.error('[restart]', 'kill target failed')
        else
            udbg.start(udbg.dbgopt)
        end
    end)
end

function event.on.uiInited()
    ui.view_module, ui.view_pages, ui.view_thread,
    ui.view_regs, ui.view_disasm, ui.memoryLayout,
    ui.view_handle, ui.view_mem, ui.menu_file,
    ui.menu_view, ui.menu_option, ui.menu_help,
    ui.menu_plugin, ui.g_status, ui.view_bplist = ui.main:find_child {
        'module', 'memoryLayout', 'thread',
        'regs', 'disasm', 'memoryLayout',
        'handle', 'memory', 'menuFile',
        'menuView', 'menuOption', 'menuHelp',
        'menuPlugin', 'status', 'bplist',
    }
    ui.view_module:add_action {
        title = '&Dump', on_trigger = function()
            local m = ui.view_module:line('.', 0)
            local path = ui.save_path {title = 'Save "'..m..'" To'}
            if path then
                ucmd {'dump-memory', '-m', m, path}
            end
        end
    }

    local lastrunning = {__mode = 'v'}
    setmetatable(lastrunning, lastrunning)
    ui.menu_help:add_menu {separator = true, index = 0}
    ui.view_task = ui.menu_help:add_menu {
        title = 'Tas&k', index = 0;

        on_trigger = function(self, name)
            local i = tonumber(name:match('%d+'))
            local task = lastrunning[i]
            log.info('try abort task:', i, task.name)
            require 'udbg.task'.try_abort(task)
        end,
        on_show = function(self)
            table.clear(lastrunning)
            self 'clear'
            for i, task in ipairs(require 'udbg.task'.running) do
                lastrunning[i] = task
                self:add_action {title = '&' .. i .. '. ' .. task.name}
            end
        end,
    }

    if windows then
        local view_thread = ui.view_thread
        view_thread:set('columns', {
            {name = 'TID', width = 6},
            {name = 'Entry', width = 30},
            {name = 'TEB', width = 14},
            {name = 'PC', width = 30},
            {name = 'Status', width = 18},
            {name = 'Priority', width = 8},
            {name = 'Suspend Count', width = 4},
            {name = 'Last Error', width = 10},
            {name = 'Name', width = 15},
        })
        view_thread:context_actions {
            {
                name = 'Goto TEB', on_trigger = function()
                    local a = parse_address(view_thread:line('.', 'TEB'))
                    ui.goto_mem(a)
                end
            },
            {
                name = 'Goto PC', on_trigger = function()
                    local a = parse_address(view_thread:line('.', 'PC'):match'%x+')
                    ui.goto_cpu(a)
                end
            },
            {
                name = '&Suspend', on_trigger = function()
                    local tid = tonumber(view_thread:line('.', 'TID'))
                    open_thread(tid):suspend()
                end
            },
            {
                name = '&Resume', on_trigger = function()
                    local tid = tonumber(view_thread:line('.', 'TID'))
                    open_thread(tid):resume()
                end
            },
            {
                name = 'Stac&k', on_trigger = function()
                    ucmd('k ' .. view_thread:line('.', 0))
                end
            },
            {
                name = 'Stack(&Fuzzy)', on_trigger = function()
                    ucmd('stack ' .. view_thread:line('.', 0))
                end
            },
        }

        ucmd.register('stack', function(args)
            local function echo(tid, th)
                if th then
                    th:suspend()
                    local sp = hex(th('reg', '_sp'))
                    log('[stack] ' .. tid .. ' sp: ' .. sp)
                    ucmd('dp -r ' .. sp .. ' 30')
                    th:resume()
                end
            end
            local tid = args[1]
            if tid == '*' then
                for tid, th in pairs(thread_list()) do
                    echo(tid, th)
                end
            else
                tid = tonumber(tid)
                echo(tid, open_thread(tid))
            end
        end)
    end

    ui.menu_option:add_action {
        title = 'Command &Cache', checked = true,
        on_trigger = function(self, val) ucmd.use_cache = val end
    }
    ui.menu_option:add_menu {separator = true}
    ui.menu_option:add_action {
        title = '&Option',
        on_trigger = ucmd.wrap 'config',
    }

    ui.view_bplist:context_actions {
        {
            name = '&Enable/Disable', shortcut = 'space';
            on_trigger = function()
                local bp = last_bplist[ui.view_bplist:get 'currentLine'.index + 1]
                if bp then
                    bp.enabled = not bp.enabled
                    ui.update_bp_list()
                end
            end
        },
        {
            name = '&Delete', shortcut = 'delete';
            on_trigger = function()
                local bp = last_bplist[ui.view_bplist:get 'currentLine'.index + 1]
                if bp then
                    bp:remove()
                    ui.update_bp_list()
                end
            end
        }
    }
end

event.on('uiInited', coroutine.create(function()
    if udbg.dbgopt.target then
        udbg.start(udbg.dbgopt)
    end
end), {order = 10000})

function ui.load_target_data()
    local path = __data_dir..'/config.json'
    data = ui.readfile(path)
    if data then
        ui.info('[config]', 'load', path)
        table.update(udbg.config, json.decode(data))
    end
    if udbg.target:status() == 'opened' then
        __config.backup_breakpoint = false
    end

    if __config.backup_breakpoint then
        local path = __data_dir..'/bplist.json'
        local data = ui.readfile(path)
        if data then
            ui.info('[bplist]', 'load', path)
            for m, list in pairs(json.decode(data)) do
                module_callback(m, function(m)
                    for _, item in ipairs(list) do
                        local a = item.symbol and parse_address(item.symbol) or m.base + item.rva
                        ui.info('[bp]', hex_line(item))
                        add_bp(a, {type = item.type, enable = item.enable})
                    end
                end)
            end
        end
    end
end

function ui.save_target_data(target)
    target = target or udbg.target
    if not target then return end

    local module_bp = {}
    for _, bp in ipairs(target:breakpoint_list()) do
        local m = target:get_module(bp.address)
        if not udbg.BPCallback[bp.id] and m then
            local info = {
                module = m.name,
                type = bp.type,
                rva = bp.address - m.base,
                symbol = target:get_symbol(bp.address),
            }
            local list = module_bp[info.module]
            if not list then
                list = table {}
                module_bp[info.module] = list
            end
            info.enable = bp.enabled
            -- log(hex_line(item))
            list:insert(info)
        end
    end

    if __config.backup_breakpoint then
        local path = __data_dir..'/bplist.json'
        ui.info('[bplist]', 'save', path)
        ui.writefile(path, json.encode(module_bp))
    end

    local path = __data_dir..'/config.json'
    ui.info('[config]', 'save', path)
    ui.writefile(path, json.encode(udbg.config))
end

ucmd.register('cpu', function(args)
    ui.goto_cpu(args[1])
end)

ucmd.register('mem', function(args)
    ui.goto_mem(args[1])
end)

ucmd.register('page', function(args)
    ui.goto_page(args[1])
end)

function event.on.targetSuccess()
    local target = udbg.target
    local image_base = target.image_base or 0

    if image_base == 0 then
        local m = target:enum_module()()
        image_base = m and m.base or 0
        target.image = m
    else
        target.image = target:get_module(image_base)
    end
    ui.goto_mem(image_base)
    if target.image then
        ui.goto_cpu(target.image.entry_point)
    end

    local name = os.path.basename(target.path)
    ui.main:set('windowTitle', name .. ' - ' .. target.pid)
    ui.g_status:set('text', target:status():gsub('^.', string.upper))
    ui.load_target_data()
end

function event.on.targetProcessCreate()
    local target = udbg.target
    if not target.image then
        target.image = target:get_module(target.image_base)
        if target.image then
            ui.goto_cpu(target.image.entry_point)
        end
    end
end

function event.on.targetEnded(target)
    ui.save_target_data(target)
    ui.request('onTargetEnded')
end

return ui