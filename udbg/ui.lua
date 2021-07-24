
require 'udbg.lua'

local class = require 'class'
local unpack = table.unpack
local rawset = rawset
local xpcall, type = xpcall, type
local traceback = debug.traceback
local ui_notify, ui_request = ui_notify, ui_request

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
    color = color,
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

---run a function in client
---@param fun function
function ui.call(fun, request)
    local ups = table {string.dump(fun)}
    for i = 2, 100 do
        local n, v = debug.getupvalue(fun, i)
        if not n then break end
        -- print('upval', n)
        ups:insert(v)
    end
    if request then
        return ui_request('call', ups)
    end
    ui_notify('call', ups)
end

do      -- ui utils
    function ui.save_path(opt)
        opt = opt or {}
        opt.type = 'file'
        opt.title = opt.title or 'Save File'
        opt.path = opt[1] or opt.path
        return ui.input(opt)
    end

    local INFO = 3
    local LOG = 4
    local WARN = 5
    local ERROR = 6
    local LOG_COLOR = 28
    local concat = string.concat
    function ui.info(...) ui_notify(INFO, concat(...)) end
    function ui.log(...) ui_notify(LOG, concat(...)) end
    function ui.warn(...) ui_notify(WARN, concat(...)) end
    function ui.error(...) ui_notify(ERROR, concat(...)) end

    local tostring = tostring
    function ui.logc(c, t, width)
        ui_notify(LOG_COLOR, {color[c] or c, tostring(t), width})
    end
    function ui.log_color_line(line)
        ui_notify(LOG_COLOR, line)
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

    function Object:add_action(opt)
        if type(opt) == 'string' and opt:find('---', 1, true) then
            opt = opt
        else
            opt = ui.action(opt)
        end
        local ctrl_id = ui_request(ADD_ACTION, {self._ctrl_id, opt})
        if type(ctrl_id) == 'number' then
            opt._ctrl_id = ctrl_id
            qobj_map[ctrl_id] = opt
            if self._root then
                handle_root(self._root, {opt._data_id, ctrl_id, 'QAction'})
            end
        end
        return opt
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

    local OPEN_PROGRAM<const> = 40
    local READ_STDOUT<const> = 41
    local READ_STDERR<const> = 42
    local WRITE_STDIN<const> = 43
    local WAIT_PROGRAM<const> = 44
    local KILL_PROGRAM<const> = 45
    local CLOSE_PROGRAM<const> = 46
    local WAIT_OUTPUT<const> = 47

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

    local Child = {}
    Child.__index = Child

    function Child:read(size)
        return ui_request(READ_STDOUT, {self.__id, size})
    end

    function Child:read_stderr(size)
        return ui_request(READ_STDERR, {self.__id, size})
    end

    function Child:wait()
        return ui_request(WAIT_PROGRAM, {self.__id, false})
    end

    function Child:try_wait()
        return ui_request(WAIT_PROGRAM, {self.__id, true})
    end

    function Child:wait_output()
        local res = ui_request(WAIT_OUTPUT, self.__id)
        self.__id = nil
        res.status = res[1]
        res.stdout = res[2]
        res.stderr = res[3]
        return res
    end

    function Child:__gc()
        ui_notify(CLOSE_PROGRAM, self.__id)
        self.__id = nil
    end

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

    function ui.program(opt)
        if type(opt) ~= 'table' then
            opt = {opt}
        end

        local args = opt
        local res = ui_request(OPEN_PROGRAM, {
            args,
            opt.stdout ~= nil and opt.stdout or false,
            opt.stderr ~= nil and opt.stderr or false,
            opt.stdin ~= nil and opt.stdin or false,
        })
        res.__id = res[1]
        res.pid = res[2]
        return setmetatable(res, Child)
    end
end

do      -- debug view
    local GOTO_CPU = 12
    local GOTO_MEM = 13
    local GOTO_PAGE = 14

    function ui.goto_cpu(a)
        ui_notify(GOTO_CPU, eval_address(a))
    end

    function ui.goto_mem(a)
        ui_notify(GOTO_MEM, eval_address(a))
    end

    function ui.goto_page(a)
        ui_notify(GOTO_PAGE, eval_address(a))
    end
end
log, logc, clog = ui.log, ui.logc, ui.clog

return ui