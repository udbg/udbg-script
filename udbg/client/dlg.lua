
local qt = require 'udbg.client.qt'

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

return mod