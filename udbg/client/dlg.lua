
local qt = require 'udbg.client.qt'
local q = qt.helper

local mod = {}

local ValueDialog = qt.Class("ValueDialog", qt.QDialog) {} do
    mod.ValueDialog = ValueDialog

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

local AboutDialog = qt.Class("AboutDialog", qt.QDialog) {} do
    mod.AboutDialog = AboutDialog

    local about = [[
Version: $version

Website: https://udbg.github.io/

Icon: https://p.yusukekamiyamane.com/

[Github](https://github.com/udbg/udbg) [Gitee](https://gitee.com/udbg/udbg)
]]

    function AboutDialog:__init()
        local flags = self:windowFlags()
        table.removevalue(flags, 'WindowContextHelpButtonHint')
        self:setWindowFlags(flags)
        self:setWindowTitle('About')
        self:setAttribute('WA_DeleteOnClose')
        self:setWindowIcon(qt.QApplication.style():standardIcon('SP_MessageBoxInformation'))
        local v = qt.QVBoxLayout(self)
        local text = require 'pl.text'.Template(about):substitute({version = g_session:request('call', 'return udbg.version')})
        local label = qt.QLabel.new(text)
        label:setTextFormat 'MarkdownText'
        label:setOpenExternalLinks(true)
        v:addWidget(label)
    end
end

do
    local comp = qt.QCompleter.new(qt.QStringList())
    comp:setMaxVisibleItems(12)
    comp:setFilterMode {'MatchContains'}
    comp:setCaseSensitivity 'CaseInsensitive'

    local rpc = g_session:requestTempMethod(function()
        return require 'udbg.service' << {
            completeSymbol = function(symbol)
                local target = udbg.target
                if not target then return {} end

                local module, name = symbol:splitv '!'
                if not name then name, module = module, nil end
                if not name then return {} end

                module = module and assert(target:get_module(module), 'get module')
                local res = table {}
                for m in module and require 'pl.seq'.list{module} or target:enum_module() do
                    for sym in m:enum_symbol(name..'*') do
                        if #res >= 320 then goto RETURN end
                        res:insert(m.name..'!'..sym.name)
                    end
                end

                ::RETURN:: return res
            end
        }
    end)

    local edit = q.QLineEdit {
        setCompleter = comp,
        setObjectName = 'lineEdit',
        ['textEdited(QString)'] = function(self)
            self:killTimer(self.completeTimer or -1)
            self.completeTimer = self:startTimer(300)
        end
    }
    function edit:timerEvent(timer)
        self:killTimer(self.completeTimer)
        local m = comp:model():cast()
        local list = g_session:request(rpc.completeSymbol, self:text():toStdString())
        m:setStringList(q.QStringList(list))
        comp:complete()
    end

    local buttonBox = qt.QDialogButtonBox.new()
    buttonBox:setOrientation(qt.Horizontal)
    buttonBox:setStandardButtons {'Cancel', 'Ok'}

    mod.addressDialog = q.QDialog {
        resize = {400, 150},
        -- setParent = g_client.ui.main,
        setWindowFlags = {"Window", "WindowCloseButtonHint", "WindowTitleHint"},
        setLayout = q.QVBoxLayout {
            edit, buttonBox
        },
    }
    buttonBox:connect("2accepted()", mod.addressDialog, "1accept()")
    buttonBox:connect("2rejected()", mod.addressDialog, "1reject()")
end

return mod