
---@language html
local about = require 'pl.text'.Template [[
Version: $version
<br/>
Tutorial:
    <a href="https://udbg.github.io/">https://udbg.github.io/</a>
<br/>
Website: <a href="https://gitee.com/udbg/udbg">https://gitee.com/udbg/udbg</a>
<br/>
Icon: <a href="https://p.yusukekamiyamane.com/">https://p.yusukekamiyamane.com/</a>
]]

local qt = require "udbg.client.qt"
return qt.inGui(function()
    local dlg = qt.QDialog(g_client.ui.main)
    local flags = dlg:windowFlags()
    table.removevalue(flags, 'WindowContextHelpButtonHint')
    dlg:setWindowFlags(flags)
    dlg:setWindowTitle('About')
    dlg:setWindowIcon(qt.QApplication.style():standardIcon('SP_MessageBoxInformation'))
    local v = qt.QVBoxLayout(dlg)
    local text = about:substitute({version = g_session:request('call', 'return udbg.version')})
    local label = qt.QLabel.new(text)
    label:setTextFormat(1)
    label:setOpenExternalLinks(true)
    v:addWidget(label)
    dlg:resize(300, dlg:height())
    dlg:exec()
end)