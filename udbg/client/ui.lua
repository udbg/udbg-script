
local qt = require 'udbg.client.qt'
local text = require 'pl.text'

local mod = {}

local config_path = os.path.join(g_client.data_dir, 'window')
qt.gui(function()
    local ws = qt.QApplication.topLevelWidgets()
    for i = 0, ws:size()-1 do
        local w = ws:value(i)
        local name = w:objectName():toStdString()
        -- print(name, w, w:metaObject():className())
        if name == 'UDbgWindow' then
            mod.main = w:cast()
            break
        end
    end
    assert(mod.main, 'MainWindow not found')
    table.update(mod, mod.main:children())

    do  -- init main window
        local conf = readfile(config_path)
        conf = conf and eval(conf) or {state = "000000ff00000000fd0000000200000002000004f00000014efc0100000001fc00000000000004f0000000b300fffffffa000000000200000006fb0000000e0064006f0063006b0043007000750100000033000001740000005800fffffefb000000140064006f0063006b004d006f00640075006c00650100000000ffffffff0000005800fffffefb000000140064006f0063006b00420070004c0069007300740100000000ffffffff0000005800fffffefb000000140064006f0063006b0054006800720065006100640100000000ffffffff0000005800fffffefb000000200064006f0063006b004d0065006d006f00720079004c00610079006f007500740100000000ffffffff0000005800fffffefb000000140064006f0063006b00480061006e0064006c00650100000000ffffffff0000005800fffffe00000003000004f00000014ffc0100000003fb000000140064006f0063006b004d0065006d006f0072007901000000000000014a0000005700fffffffb000000120064006f0063006b0053007400610063006b010000014e000001460000005700fffffffb0000000e0064006f0063006b004c006f00670100000298000002580000013b00ffffff000004f00000000000000004000000040000000800000008fc0000000100000002000000010000000e0074006f006f006c0042006100720100000000ffffffff0000000000000000"}
        conf = table.map(function(v)
            v = v:fromhex()
            return qt.QByteArray(v, #v)
        end, conf)
        if conf.geometry then mod.main:restoreGeometry(conf.geometry) end
        if conf.state then mod.main:restoreState(conf.state) end

        local style = text.Template [[
            QAbstractScrollArea {
                background-color: rgb(255, 248, 240);
                font: $font;
            }

            QAbstractScrollArea:focus {
                border: 1px solid #0078d7;
            }
        ]]
        local styleOpt = {font = os.name == 'windows' and '8pt "Lucida Console"' or '10pt "DejaVu Sans Mono"'}
        mod.main:setStyleSheet(style:substitute(styleOpt))
    end

    setmetatable(mod, {
        __index = function(self, key)
            if type(key) ~= 'string' then return end
            local child = self.main:findChild(key)
            if child then
                rawset(self, key, child)
                return child
            end
        end,
        __call = function(self, fun, ...)
            return qt.gui(fun, ...)
        end,
    })

    function mod.init_recently()
        mod.menuRecent:clear()
        local i = 0
        for path in g_client.db:urows 'SELECT path FROM target_history ORDER BY time DESC' do
            i = i + 1
            if i > 30 then break end
            local action = qt.action {
                text = '&' .. i .. '. ' .. path,
                on_trigger = function(self)
                    g_session:notify('call', "udbg.start {open = false, attach = false, target = ...}", self.path)
                end
            }
            action.path = path
            mod.menuRecent:addAction(action)
        end
    end

    local stat
    function mod.add_recently(path)
        stat = stat or assert(g_client.db:prepare "REPLACE INTO target_history (path) VALUES(?)", g_client.db:error_message())
        stat:bind_values(path); stat:step(); stat:reset()
        mod.init_recently()
    end
    mod.init_recently()

    local WindowFilter = qt.Class('MainFilter', qt.QObject) {} do
        local eventFilter = {
            -- [qt.QEvent.Close] = function(obj, event)
            Close = function(obj, event)
                local exit = true
                if g_session then
                    if g_session:request('call', "return udbg.target and udbg.target:status() ~= 'opened'") then
                        local dlg = qt.QDialog(mod.main)
                        dlg:setWindowTitle 'Target is running'
                        local verticalLayout = qt.QVBoxLayout.new(dlg)
                        verticalLayout:addWidget(qt.QLabel.new 'Really exit?')
                        local buttonBox = qt.QDialogButtonBox.new(qt.QDialogButtonBox.Cancel|qt.QDialogButtonBox.Ok, qt.Horizontal)
                        verticalLayout:addWidget(buttonBox)
                        buttonBox:connect("2accepted()", dlg, "1accept()")
                        buttonBox:connect("2rejected()", dlg, "1reject()")
                        exit = dlg:exec() == qt.QDialog.Accepted
                        if exit then
                            g_session:request('call', 'ui.save_target_data()')
                        end
                    end
                end
                if exit then
                    g_client:finallyExit(0)
                else
                    event:ignore()
                end
                return true
            end,
            DragEnter = function(obj, event)
                event:acceptProposedAction()
                return true
            end,
            Drop = function(obj, event)
                local urls = event:mimeData():urls()
                if urls:isEmpty() then return end
                for i, url in qt.listIter(urls) do
                    local path = url:toLocalFile():toStdString()
                    g_session:notify('call', 'udbg.start(...)', {target = path})
                    break
                end
            end,
        }
        function WindowFilter:eventFilter(obj, event)
            assert(event, 'no event')
            if obj == mod.command then
                if event:type() == 'KeyPress' then
                    -- log(event:modifiers(), event:text():toStdString())
                end
            else
                -- print(event:type())
                local handler = eventFilter[event:type()]
                if handler then
                    return handler(obj, event) or false
                end
            end
            return false
        end
    end
    local filter = WindowFilter.new()
    mod.main:installEventFilter(filter)
    -- mod.command:installEventFilter(filter)
end, true)

mod.init = qt.inGui(function()
    local ValueDialog = qt.Class("ValueDialog", qt.QDialog) {} do
        function ValueDialog:__init(value)
            local flags = self:windowFlags()
            table.removevalue(flags, 'WindowContextHelpButtonHint')
            self:setWindowFlags(flags)
            local ValueDialog = self
            -- generate widget
            ValueDialog:resize(424, 154)
            ValueDialog:setWindowTitle("Input Value")
            local verticalLayout = qt.QVBoxLayout.new(ValueDialog); self.verticalLayout = verticalLayout
            verticalLayout:setObjectName("verticalLayout")
            local formLayout = qt.QFormLayout.new(); self.formLayout = formLayout
            formLayout:setObjectName("formLayout")
            local label = qt.QLabel.new(); self.label = label
            label:setObjectName("label")
            label:setText("Expression")
            formLayout:setWidget(0, 0, label)
            local expr = qt.QLineEdit.new(); self.expr = expr
            expr:setObjectName("expr")
            formLayout:setWidget(0, 1, expr)
            local label_2 = qt.QLabel.new(); self.label_2 = label_2
            label_2:setObjectName("label_2")
            label_2:setText("Hexiadecimal")
            formLayout:setWidget(1, 0, label_2)
            local hex = qt.QLineEdit.new(); self.hex = hex
            hex:setObjectName("hex")
            hex:setReadOnly(true)
            formLayout:setWidget(1, 1, hex)
            local label_3 = qt.QLabel.new(); self.label_3 = label_3
            label_3:setObjectName("label_3")
            label_3:setText("Decimal")
            formLayout:setWidget(2, 0, label_3)
            local dec = qt.QLineEdit.new(); self.dec = dec
            dec:setObjectName("dec")
            dec:setEnabled(false)
            formLayout:setWidget(2, 1, dec)
            verticalLayout:addLayout(formLayout)
            local buttonBox = qt.QDialogButtonBox.new(); self.buttonBox = buttonBox
            buttonBox:setObjectName("buttonBox")
            buttonBox:setOrientation(qt.Horizontal)
            buttonBox:setStandardButtons(qt.QDialogButtonBox.Cancel|qt.QDialogButtonBox.Ok)
            verticalLayout:addWidget(buttonBox)
            -- generate connections
            buttonBox:connect("2accepted()", ValueDialog, "1accept()")
            buttonBox:connect("2rejected()", ValueDialog, "1reject()")

            expr:connect('2textChanged(QString)', function(self, text)
                text = text:toStdString()
                local hexText = text:gsub('[^%x]+', '')
                if #hexText then
                    hex:setText(hexText)
                    dec:setText(tostring(tonumber(hexText, 16)))
                end
                if text ~= hexText then
                    expr:setStyleSheet 'border: 1px solid red;'
                else
                    expr:setStyleSheet ''
                end
            end)
            if value then
                expr:setText(tostring(value))
            end
        end

        function ValueDialog:value()
            return tonumber(self.hex:text():toStdString():gsub('^0[xX]', ''), 16)
        end
    end

    if os.name == 'windows' then
        local ffi = require 'ffi'
        ffi.cdef [[
            typedef void *HWND;
            void SetForegroundWindow(HWND);
            HWND GetConsoleWindow();
        ]]
        -- print(ffi.C.GetConsoleWindow())

        qt.connect(mod.actionConsole, 'triggered()', function()
            ffi.C.SetForegroundWindow(ffi.C.GetConsoleWindow())
        end)
        qt.connect(mod.actionSwitchToConsole, 'triggered()', function()
            ffi.C.SetForegroundWindow(ffi.C.GetConsoleWindow())
            mod.main:hide()
            g_session:notify('call', "ui.cuiMode = true")
        end)
    end

    local updateDisasm = qt.getMetaCall(mod.disasm, 'update()')
    local updateMemory = qt.getMetaCall(mod.memory, 'update()')

    local function getTableCell(w, cols)
        for _, col in ipairs(cols) do
            local r = qt.metaCall(w, 'getCell(QString)', qt.QString(col))
            if not r:isEmpty() then
                return tonumber(r:toStdString():match('0?[xX]?(%x+)'), 16)
            end
        end
    end

    local function getWidgetMemoryEntry(w, name)
        local a = qt.metaGet(w, 'cursorAddress')
        if a then return a:value() end
        -- if qt.isInstanceOf(w, qt.QPlainTextEdit) then
        if w.textCursor then
            local selected = w:textCursor():selectedText()
            if selected:size() > 0 then
                local a = g_session:request('call_global', {'eval_address', selected:toStdString()})
                return a
            end
        elseif w == mod.stack then
            local r = qt.metaCall(mod.stack, 'currentLineText(int)', 0)
            if not r:isEmpty() then
                return tonumber(r:toStdString():match('0?[xX]?(%x+)'), 16)
            end
        else
            return getTableCell(w, {'Base', 'Address', 'TEB'})
        end
    end
    local function getWidgetCodeEntry(w, name)
        return getTableCell(w, {'Entry'})
    end
    local codeEntry = {
        module = getWidgetCodeEntry,
        thread = getWidgetCodeEntry,
    }
    local memoryEntry = {}

    qt.slotObject:__addslot('on_gotoCpu()', function()
        local wid = mod.main:focusWidget()
        local name = wid:objectName():toStdString()
        local get = codeEntry[name] or getWidgetMemoryEntry
        local a = get and get(wid, name)
        if a then
            g_session('call_global', 'ui.goto_cpu', a)
        end
    end)
    qt.slotObject:__addslot('on_gotoMemory()', function()
        local wid = mod.main:focusWidget()
        local name = wid:objectName():toStdString()
        local get = memoryEntry[name] or getWidgetMemoryEntry
        local a = get and get(wid, name)
        if a then
            g_session('call_global', 'ui.goto_mem', a)
        end
    end)
    qt.slotObject:__addslot('on_gotoPage()', function()
        local wid = mod.main:focusWidget()
        local name = wid:objectName():toStdString()
        local get = memoryEntry[name] or getWidgetMemoryEntry
        local a = get and get(wid)
        if a then
            g_session('call_global', 'ui.goto_page', a)
        end
    end)

    mod.actionGotoCPU = qt.action {
        text = 'Goto &CPU',
        shortcut = 'C',
        icon = ':/ico/res/cpu.ico',
    }
    mod.actionGotoMemory = qt.action {
        text = 'Goto &Memory',
        shortcut = 'M',
        icon = ':/ico/res/memory-map.png',
    }
    mod.actionGotoPage = qt.action {
        text = 'Goto &Page',
        shortcut = 'P',
        icon = ':/ico/res/memory-map.png',
    }
    mod.actionFollowInMemory = qt.action {
        icon = ':/ico/res/memory-map.png',
        text = 'Follow in Memory',
        shortcut = 'Shift+M',
    }

    do  -- init option menu
        mod.menuOption:addAction(qt.action {
            text = '&Data Folder',
            icon = ':/ico/res/folder-horizontal-open.png',
            on_trigger = function()
                -- os.execute('start '..g_client.data_dir)
                qt.QDesktopServices.openUrl(qt.QUrl(g_client.data_dir:gsub('\\', '/'), 'TolerantMode'))
            end
        })
        mod.menuOption:addAction(qt.action {
            text = '&Edit Config',
            -- icon = ':/ico/res/folder-horizontal-open.png',
            on_trigger = function()
                g_client:edit_script(g_client.config_path)
            end
        })
    end

    do  -- init tool bar
        local spacer = qt.QWidget.new(mod.main)
        spacer:setSizePolicy('Expanding', 'Expanding')
        mod.toolBar:addWidget(spacer)
        -- mod.toolBar:addWidget(qt.QLabel.new 'Engine')
        local engines = qt.QComboBox.new()
        local keys = g_session:request('call', 'return udbg.engine')
        for _, val in ipairs(keys) do
            if type(val) == 'string' then
                engines:addItem(val)
            end
        end
        mod.toolBar:addWidget(engines)

        engines:connect(qt.SIGNAL'currentIndexChanged(QString)', function(self, which)
            which = which:toStdString()
            g_session:notify('call', 'udbg.dbgopt.adaptor = ...', which)
            log.info('[engine]', 'use', which)
        end)
    end

    local virtualTableID = {
        stack = mod.stack:__ptr(),
    }
    local rpc = g_session << function()
        local ui = require 'udbg.ui'
        local view = require 'udbg.view'
        -- print('stack', hex(virtualTableID.stack))
        ui.stack = view.StackView(virtualTableID.stack)
        return require 'udbg.service' << {
            get_symbol = function(a)
                return {udbg.target:get_symbol(a, true)}
            end,
            parse_address = function(a)
                return udbg.target:parse_address(a)
            end,
            disasm_jump = function(a)
                local insn = disasm(a)
                if insn then
                    local ot, val = insn('operand', 0)
                    if ot == 'mem' then
                        val = val and read_ptr(val)
                    elseif ot ~= 'imm' then
                        val = nil
                    end
                    if val then
                        ui.goto_cpu(val)
                    end
                end
            end,
            disasm_jumpmem = function(a)
                local insn = disasm(a)
                if insn then
                    for i = 0, 5 do
                        local ot, val = insn('operand', i)
                        if ot == 'mem' then
                            return val and ui.goto_mem(val)
                        end
                    end
                end
            end,
            set_reg = function(name, val)
                _ENV.reg[name] = val
            end,
            _stack = function(cmd, ...)
                local ctrl = ui.stack
                local method = ctrl[cmd]
                if method and ctrl:isAlive() then
                    return method(ctrl, ...)
                end
            end,
        }
    end

    qt.slotObject:__addslot('on_followInMemory()', function(self)
        local w = mod.main:focusWidget()
        local a = qt.metaGet(w, 'cursorAddress')
        if a then
            -- for memory view
            g_session:notify(rpc.disasm_jumpmem, a:value())
        else
            -- for stack view
            local r = qt.metaCall(w, 'currentLineText(int)', 1)
            if r and not r:isEmpty() then
                a = tonumber(r:toStdString():match('0?[xX]?(%x+)'), 16)
                g_session:notify('call', 'ui.goto_mem(...)', a)
            end
        end
    end)

    qt.slotObject:__addslot('on_cpumem_cursorMoved()', function(self)
        local sender = self:sender()
        local a = qt.metaGet(sender, 'cursorAddress'):toULongLong()
        local m, sym, offset, base = table.unpack(g_session:request(rpc.get_symbol, a))
        sym = sym or ''
        local r = ''
        if m then
            local off = a - base
            r = m .. "+" .. hex(off)

            if #sym > 80 then
                sym = sym:sub(80)
                sym = sym .. " ..."
            end
            if #sym > 0 then
                r = r .. " " .. sym
                if offset ~= 0 then
                    r = r.." +"..hex(offset)
                end
            end
        end
        mod.symbolStatus:setText(hex(a)..': '..r)
    end)

    do  -- init disasm view
        mod.disasm:addAction(mod.actionGotoMemory)
        mod.disasm:addAction(mod.actionGotoPage)
        qt.connect(mod.disasm, 'doubleClicked()', function()
            if g_client.target_alive then
                local a = qt.metaGet(mod.disasm, 'cursorAddress'):toULongLong()
                g_session:notify(rpc.disasm_jump, a)
            end
        end)
        mod.disasm:addAction(qt.action {
            icon = ':/ico/res/breakpoint.png',
            text = 'Breakpoint',
            shortcut = 'F2',
            on_trigger = function()
                local a = qt.metaGet(mod.disasm, 'cursorAddress'):toULongLong()
                local _ = g_session << function()
                    local bp = get_breakpoint(a)
                    if bp then
                        if bp.enabled then
                            bp.enabled = false
                        else
                            bp:remove()
                        end
                    else
                        add_bp(a)
                    end
                end
                updateDisasm()
            end
        })
        mod.disasm:addAction(mod.actionFollowInMemory)
        mod.disasm:addAction(qt.action {
            name = 'actionRunToCursor',
            icon = ':/ico/res/arrow-run-cursor.png',
            text = 'Run To Cursor',
            shortcut = 'F4',
            on_trigger = function()
                local a = qt.metaGet(mod.disasm, 'cursorAddress'):toULongLong()
                g_session:notify('call_global', {'ui.continue', 'goto', a})
            end
        })
    end

    do  -- init memory view
        mod.memory:addAction(mod.actionGotoCPU)
        mod.memory:addAction(mod.actionGotoPage)
        mod.memory:addAction(qt.action {
            icon = ':/ico/res/breakpoint.png',
            text = 'Breakpoint',
            shortcut = 'F2',
            on_trigger = function()
            end
        })
        mod.memory:addAction(qt.action {
            text = 'Follow Memory',
            shortcut = 'Space',
            on_trigger = function()
                local a = qt.metaGet(mod.main:focusWidget(), 'cursorAddress'):toULongLong()
                g_session(function()
                    local p = read_ptr(a)
                    if p then ui.goto_mem(p) end
                end)
            end
        })
        mod.memory:addAction(qt.action {
            text = 'Follow Disasm',
            shortcut = 'F12',
            on_trigger = function()
                local a = qt.metaGet(mod.main:focusWidget(), 'cursorAddress'):toULongLong()
                g_session(function()
                    local p = read_ptr(a)
                    if p then ui.goto_cpu(p) end
                end)
            end
        })

        local memType = {[0] = 'u8', [1] = 'u16', [2] = 'u32', [3] = 'u64', [4] = 'f', [5] = 'd'}
        qt.connect(mod.memory, 'valueEditing()', function(self)
            if g_client.target_alive then
                local mem = self:sender()
                local ty = memType[qt.metaGet(mem, 'dataType'):toInt()]
                local a = qt.metaGet(mem, 'cursorAddress'):toULongLong()
                local val = ty and g_session:request('call_global', 'read_type', a, ty)
                if val then
                    local dlg = ValueDialog({mod.main}, '%x' % val)
                    dlg:setWindowTitle('Edit '..ty..'@'..hex(a))
                    if dlg:exec() == qt.QDialog.Accepted then
                        g_session:request('call_global', 'write_type', a, ty, dlg:value())
                        qt.metaCall(mem, 'update()')
                    end
                end
            end
        end)
    end

    do  -- init status bar
        mod.status = qt.QLabel.new(mod.statusBar)
        mod.status:setObjectName 'status'
        mod.status:setMinimumWidth(200)
        mod.status:setText 'Ready'
        mod.symbolStatus = qt.QLabel.new(mod.statusBar)
        mod.statusBar:addPermanentWidget(mod.status)
        mod.statusBar:addPermanentWidget(mod.symbolStatus, 1)
    end

    do  -- init stack view
        mod.stack:addAction(mod.actionGotoCPU)
        mod.stack:addAction(mod.actionGotoMemory)
        mod.stack:addAction(mod.actionGotoPage)
        mod.stack:addAction(mod.actionFollowInMemory)
        qt.metaSet(mod.stack, 'RpcMethod', rpc._stack)
    end

    mod.thread:addAction(mod.actionGotoCPU)
    mod.thread:addAction(mod.actionGotoMemory)
    mod.thread:connect('2doubleClicked()', mod.actionGotoCPU, '1trigger()')

    mod.texLog:addAction(mod.actionGotoCPU)
    mod.texLog:addAction(mod.actionGotoMemory)
    mod.texLog:addAction(mod.actionGotoPage)

    do  -- init regs view
        mod.regs:addAction(mod.actionGotoCPU)
        mod.regs:addAction(mod.actionGotoMemory)
        mod.regs:addAction(mod.actionGotoPage)
        qt.connect(mod.regs, 'valueEditing(QString,qulonglong)', function(self, reg, value)
            if g_client.target_alive then
                local name = reg:toStdString()
                -- local regs = self:sender()
                local dlg = ValueDialog({mod.main}, '%x' % value)
                dlg:setWindowTitle('Edit register: '..name)
                if dlg:exec() == qt.QDialog.Accepted then
                    g_session:request(rpc.set_reg, name:lower(), dlg:value())
                    g_session:notify('call', [[ui.view_regs('setRegs', udbg.target:register())]])
                end
            end
        end)
    end

    mod.memoryLayout:addAction(mod.actionGotoCPU)
    mod.memoryLayout:addAction(mod.actionGotoMemory)
    mod.memoryLayout:connect('2doubleClicked()', mod.actionGotoMemory, '1trigger()')

    mod.bplist:addAction(mod.actionGotoCPU)
    mod.bplist:addAction(mod.actionGotoMemory)
    mod.bplist:addAction(mod.actionGotoPage)
    mod.bplist:connect('2doubleClicked()', mod.actionGotoCPU, '1trigger()')

    mod.module:addAction(mod.actionGotoCPU)
    mod.module:addAction(mod.actionGotoMemory)
    mod.module:addAction(mod.actionGotoPage)
    mod.module:connect('2doubleClicked()', mod.actionGotoCPU, '1trigger()')

    mod.symbol:addAction(mod.actionGotoCPU)
    mod.symbol:addAction(mod.actionGotoMemory)
    mod.symbol:addAction(mod.actionGotoPage)
    mod.symbol:connect('2doubleClicked()', mod.actionGotoCPU, '1trigger()')

    do  -- initCommand
        local cmdType = mod.main:findChild 'cmdType'
        cmdType:addItem 'udbg'
        cmdType:addItem 'lua'
        cmdType:addItem 'eng'

        qt.connect(mod.command, 'returnPressed()', function()
            qt.singleShotTimer(10, function()
                local cmdline = qt.metaCall(mod.command, 'addHistoryClear()'):trimmed()
                if cmdline:isEmpty() then return end

                local ty, cmdline = cmdType:currentText():toStdString(), cmdline:toStdString()
                g_client.service.clientCommand {cmdline, ty}
            end)
        end)

        -- collect commands
        local result = qt.QStringList()
        for _, dir in ipairs(g_client.plugin_dirs) do
            for p in os.glob(os.path.join(dir, 'udbg', 'command', '*')) do
                local cmd = os.path.splitext(os.path.basename(p))
                result:push_back(cmd)
            end
        end
        local ucmd = require 'udbg.cmd'
        for cmd, _ in pairs(ucmd.cache) do
            result:push_back(cmd)
        end
        qt.metaSet(mod.command, 'completeList', result)

        local command_history = qt.QStringList()
        for cmdline in g_client.db:urows 'SELECT cmdline FROM command_history ORDER BY time ASC' do
            g_client:add_history(cmdline)
            command_history:prepend(cmdline)
        end
        qt.metaSet(mod.command, 'history', command_history)
    end

    local function call(script)
        return function() g_session:notify('call', script) end
    end
    qt.connect(mod.actionStepOut, 'triggered()', call "ui.continue('stepout')")
    qt.connect(mod.actionStepIn, 'triggered()', call "ui.continue('step')")
    qt.connect(mod.actionRun, 'triggered()', call "ui.continue('run', false)")
    qt.connect(mod.actionHandled, 'triggered()', call "ui.continue('run', true)")
    qt.connect(mod.actionRunToReturn, 'triggered()', call "ui.continue('go_ret')")

    qt.connect(mod.actionAttach, 'triggered()', call "ucmd 'list-process'")
    qt.connect(mod.actionDetach, 'triggered()', call "ui.detach_target()")
    qt.connect(mod.actionStop, 'triggered()', call "ui.stop_target()")
    qt.connect(mod.actionPause, 'triggered()', call "udbg.target:pause()")
    qt.connect(mod.actionRestart, 'triggered()', call "ui.restart_target()")

    local args = g_client.arguments
    if args.remote then
        local menu = qt.QMenu.new(
            args.remote == args.real_remote and
            args.remote or '%s(%s)' % {args.remote, args.real_remote}
        )
        menu:setEnabled(false)
        mod.menuBar:addMenu(menu)
    end

    function mod.findChild(qobj, class)
        for name, wid in pairs(qobj:children()) do
            if qt.isInstanceOf(wid, qt.QWidget) then
                -- log(name, wid)
                -- while qt.isInstanceOf(wid, qt.QSplitter) do
                --     wid = wid:widget(0)
                --     name = wid:objectName():toStdString()
                -- end
                if qt.isInstanceOf(wid, class) then
                    return name, wid
                end
                name, wid = mod.findChild(wid, class)
                if wid then
                    return name, wid
                end
            end
        end
    end

    qt.slotObject:__addslot('on_tabifiedDockWidgetActivated(QDockWidget*)', function(self, dock)
        local name, wid = mod.findChild(dock:widget(), qt.QAbstractScrollArea)
        if wid then
            -- log(name, wid)
            wid:setFocus()
            g_session:notify('call_global', {'ui.update_view', name})
        end
    end)

    qt.slotObject:__addslot('on_cpuMemKeyPress(QKeyEvent*)', function(self, key)
        if key:key() == qt.Key_G and table.concat(key:modifiers()) == 'ControlModifier' then
            key:accept()
            local lineEdit = mod.addressDialog:findChild'lineEdit'
            qt.singleShotTimer(10, function()
                qt.metaCall(lineEdit, 'popupHistory()')
            end)
            if mod.addressDialog:exec() > 0 then
                local a = qt.metaCall(lineEdit, 'addHistoryClear()'):trimmed()
                if not a:isEmpty() then
                    a = g_session:request(rpc.parse_address, a:toStdString())
                    a = a and qt.metaSet(self:sender(), 'address', a)
                end
            end
        end
    end)

    qt.connect(mod.actionAbout, 'triggered()', function() require 'udbg.client.about'() end)

    local timerUpdate = qt.QTimer.new(mod.main)
    local count = 0
    timerUpdate:connect('2timeout()', function()
        if mod.main:isVisible() and mod.actionAutoUpdate:isChecked() then
            count = count + 1
            updateMemory()
            updateDisasm()
            g_session:notify('call_global', {'ui.update_view', 'thread'})
            if count % 2 == 0 then
                g_session:notify('call_global', {'ui.update_view', 'module'})
            end
        end
    end)

    mod.onTargetStart = qt.inGui(function()
        mod.main:connect(qt.SIGNAL'tabifiedDockWidgetActivated(QDockWidget*)', qt.slotObject, qt.SLOT'on_tabifiedDockWidgetActivated(QDockWidget*)')
        mod.disasm:connect(qt.SIGNAL'cursorMoved()', qt.slotObject, qt.SLOT'on_cpumem_cursorMoved()')
        mod.memory:connect(qt.SIGNAL'cursorMoved()', qt.slotObject, qt.SLOT'on_cpumem_cursorMoved()')
        mod.disasm:connect(qt.SIGNAL'keyPress(QKeyEvent*)', qt.slotObject, qt.SLOT'on_cpuMemKeyPress(QKeyEvent*)')
        mod.memory:connect(qt.SIGNAL'keyPress(QKeyEvent*)', qt.slotObject, qt.SLOT'on_cpuMemKeyPress(QKeyEvent*)')

        mod.actionGotoCPU:connect(qt.SIGNAL'triggered()', qt.slotObject, qt.SLOT'on_gotoCpu()')
        mod.actionGotoMemory:connect(qt.SIGNAL'triggered()', qt.slotObject, qt.SLOT'on_gotoMemory()')
        mod.actionGotoPage:connect(qt.SIGNAL'triggered()', qt.slotObject, qt.SLOT'on_gotoPage()')
        mod.actionFollowInMemory:connect(qt.SIGNAL'triggered()', qt.slotObject, qt.SLOT'on_followInMemory()')

        timerUpdate:start(500)
        -- timerUpdate:start(5)
    end)

    mod.onTargetEnd = qt.inGui(function()
        timerUpdate:stop()

        mod.main:disconnect(qt.slotObject)
        mod.memory:disconnect(qt.slotObject)
        mod.disasm:disconnect(qt.slotObject)

        mod.actionGotoCPU:disconnect(qt.slotObject)
        mod.actionGotoMemory:disconnect(qt.slotObject)
        mod.actionGotoPage:disconnect(qt.slotObject)
        mod.actionFollowInMemory:disconnect(qt.slotObject)
    end)

    mod.onClosed = qt.inGui(function()
        writefile(config_path, pretty * {
            geometry = mod.main:saveGeometry():toStdString():tohex(),
            state = mod.main:saveState():toStdString():tohex(),
        })
    end, true)
end, true)

return mod