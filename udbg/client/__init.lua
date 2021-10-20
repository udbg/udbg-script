
local qt = require 'udbg.client.qt'

local parser = [[
.exec                           execute a script
    <path> (optional string)    the script path

    -w, --watch                 watch the script
    -e, --edit                  edit this script
    --list-watch
]]

ucmd.register('.exec', function(argv)
    if argv.path then
        g_client:execute_bin(argv.path, argv)
    elseif argv.list_watch then
        local watch_cache = g_client.watch_cache
        local k = next(watch_cache, #watch_cache)
        while k do
            local i = watch_cache[k]
            log(i, watch_cache[i], k)
            k = next(watch_cache, k)
        end
    end
end, parser)

ucmd.register('.show', function(argv)
    os.execute('explorer.exe /select,"' .. argv[1] .. '"')
    -- client.qt.QDesktopServices.openUrl(client.qt.QUrl(argv[1]:gsub('\\', '/'), 'TolerantMode'))
end)

ucmd.register('.edit', function(argv)
    local path = assert(argv[1], 'no path')
    os.execute(g_client.config.edit_cmd:gsub('%%1', path))
end)

local q = qt.helper
ucmd.register('.pe-view', function(argv)
    local base = assert(argv[1])
    qt.gui(function()
        local rpc = g_session:requestTempMethod(function()
            base = udbg.target:eval_address(base)
            local pe = assert(require 'pefile'.FromAddress(base))
            local res = require 'udbg.service' << {
                basicinfo = function()
                    local secs = pe.SectionList
                    local sections = table {'[section] #'..tostring(#secs)}
                    for i, item in ipairs(secs) do
                        local data = read_bytes(base + item.VirtualAddress, item.VirtualSize)
                        local md5 = data and math.md5(data):tohex() or '<read failure>'
                        sections:insert(table {hex(base + item.VirtualAddress), hex(item.VirtualSize),  hex(item.SizeOfRawData), item.Name, md5}:concat '\t')
                    end
                    if pe.DebugInfo then
                        pe.DebugInfo.signature = pe.DebugInfo.signature:tohex()
                    end
                    return {sections = sections:concat'\n', FileHeader = pe.FileHeader, OptionalHeader = pe.OptionalHeader, DebugInfo = pe.DebugInfo}
                end,
                imports = function()
                    local res = table {}
                    for _, item in ipairs(pe.ImportList or {}) do
                        local childs = table {}
                        for imp in pe:EachImportItem(item) do
                            childs:insert({imp.Number, imp.Name or ''})
                        end
                        item.childs = childs
                        res:insert(item)
                    end
                    return res
                end,
                exports = function()
                    local res = table {}
                    for _, item in ipairs(pe.ExportList or {}) do
                        res:insert({item.Number, hex(item.Address), item.Name})
                    end
                    return res
                end,
                searchImports = function()
                    -- build all exports
                    local exports = {}
                    for m in udbg.target:enum_module() do
                        if m.base ~= base then
                            -- log (m.name, m.path)
                            local mbase = m.base
                            local mname = m.name
                            for s in m:enum_export() do
                                exports[mbase + s.offset] = {
                                    module = mname,
                                    name = s.name,
                                    offset = s.offset,
                                    base = mbase,
                                }
                            end
                        end
                    end
    
                    -- TODO: 地址连续的为一组，不连续的存疑
                    --       data段的可信度高、bss段 text段 存疑
                    -- 构造完导入表后 传递给 PeUtil 进行dump
                    local secs = pe.SectionList
                    local psize = pe.IS64 and 8 or 4
                    local pfmt = pe.IS64 and 'I8' or 'I4'
                    local result = table {}
                    local IMAGE_SCN_MEM_EXECUTE = 0x20000000
                    for i, sec in ipairs(secs) do
                        if sec.Characteristics & IMAGE_SCN_MEM_EXECUTE == 0 then
                            local lastmodule
                            local curlib
                            local data = read_bytes(sec.Address, sec.VirtualSize) or ''
                            log('-----', sec.Name, hex(#data))
                            for offset = 1, #data - #data % psize, psize do
                                local rva = sec.VirtualAddress + offset - 1
                                local p = pfmt:unpack(data, offset)
                                local item = p and exports[p]
                                if item then
                                    if lastmodule ~= item.module then
                                        lastmodule = item.module
                                        curlib = {
                                            section = sec.Name,
                                            IAT = rva,
                                            funcs = {},
                                            name = lastmodule,
                                        }
                                        result:insert(curlib)
                                    end
                                    -- log(' ', hex(rva), hex(item.offset), item.name)
                                    table.insert(curlib.funcs, {name = item.name, rva = rva, ptr = p})
                                end
                            end
                        end
                    end
                    return result
                end,
                dump = function(imports, save_path)
                    local pu = PEUtil.from_base(base)
                    if imports and #imports > 0 then
                        -- log('imports', imports)
                        pu:add_imports(imports)
                    end
                    pu:write_to_file(save_path)
                    ui.info('save', 'to', save_path)
                end,
            }
            return res
        end)
        -- package.loaded.qthelper = nil
        local dlg = q.QDialog {
            resize = {0.5, 0.5},
            setWindowTitle = 'PE: '..base,
            setWindowFlags = {"Window", 'WindowMinMaxButtonsHint', "WindowCloseButtonHint", "WindowTitleHint"},
            setLayout = q.QVBoxLayout {
                q.QTabWidget {
                    q.QWidget{setWindowTitle = '&Header', setLayout = q.QVBoxLayout {
                        q.QPlainTextEdit {
                            setObjectName = 'basicInfo',
                            setReadOnly = true,
                        },
                    }},
                    q.QWidget{setWindowTitle = '&Import', setLayout = q.QVBoxLayout {
                        q.QTreeWidget {
                            setObjectName = 'import',
                            columns = {
                                {name = 'Number', width = 80},
                                {name = 'Name', width = 500},
                            },
                        },
                    }},
                    q.QWidget{setWindowTitle = '&Export', setLayout = q.QVBoxLayout {
                        q.QTreeWidget {
                            setObjectName = 'export',
                            columns = {
                                {name = 'Number', width = 80},
                                {name = 'Address', width = 180},
                                {name = 'Name', width = 500},
                            },
                        },
                    }},
                    q.QWidget{setWindowTitle = '&Dump', setLayout = q.QVBoxLayout {
                        q.QTreeWidget {
                            setObjectName = 'dumpImport',
                            columns = {
                                {name = 'RVA', width = 180},
                                {name = 'Name', width = 400},
                                {name = 'Section', width = 80},
                            },
                        },
                        q.QHBoxLayout {
                            q.Strech,
                            q.QPushButton {
                                setText = 'Delete',
                                ['clicked()'] = function(self)
                                    local impTree = self:window():findChild 'dumpImport'
                                    local item = impTree:currentItem()
                                    if item then
                                        item:delete()
                                    end
                                end,
                            },
                            q.QPushButton {
                                setText = 'SearchImport',
                                ['clicked()'] = function(self)
                                    local impTree = self:window():findChild 'dumpImport'
                                    impTree:clear()
                                    for _, item in ipairs(g_session:request(rpc.searchImports)) do
                                        local ti = q.QTreeWidgetItem {
                                            hex(item.IAT), item.name, item.section,
                                            childs = table.imap(function(func)
                                                return {hex(func.rva), func.name, hex(func.ptr)}
                                            end, item.funcs)
                                        }
                                        ti.data = item
                                        impTree:addTopLevelItem(ti)
                                    end
                                end,
                            },
                            q.QPushButton {
                                setText = 'Dump',
                                ['clicked()'] = function(self)
                                    local impTree = self:window():findChild 'dumpImport'
                                    local path = qt.QFileDialog.getSaveFileName(self:window(), 'save dump', '.', 'PE Files (*.exe *.dll *.sys);;All Files(*)')
                                    if not path:isEmpty() then
                                        path = path:toStdString()
                                        local imports = table.imap(function(item)
                                            local funcs = table {}
                                            item.data.funcs = funcs
                                            for i = 0, item:childCount()-1 do
                                                local child = item:child(i)
                                                local name = child:text(1):toStdString()
                                                funcs:insert(name)
                                            end
                                            return item.data
                                        end, impTree:topLevelItems())
                                        g_session:notify(rpc.dump, imports, path)
                                    end
                                end,
                            },
                        },
                    }},
                },
            },
        }

        dlg:show(); dlg:raise()
        local ui = dlg:namedChildren()

        local pefile = require 'pefile'
        local info = g_session:request(rpc.basicinfo)
        local fhdr = info.FileHeader
        fhdr.Machine = hex(fhdr.Machine)..' '..(pefile.Machine[fhdr.Machine] or '')
        local ohdr = info.OptionalHeader
        ohdr.Subsystem = hex(ohdr.Subsystem)..' '..(pefile.Subsystem[ohdr.Subsystem] or '')
        ohdr.DllCharacteristics = hex(ohdr.DllCharacteristics)..' '..(pefile.DllCharacteristics[ohdr.DllCharacteristics] or '')

        ui.basicInfo:setPlainText(table {
            'FileHeader: ' .. pretty * info.FileHeader,
            'OptionalHeader: ' .. pretty * info.OptionalHeader,
            info.sections,
            'DebugInfo: ' .. pretty * info.DebugInfo
        }:concat '\n')

        for _, r in ipairs(g_session:request(rpc.exports)) do
            ui.export:addTopLevelItem(q.QTreeWidgetItem(r))
        end

        for _, r in ipairs(g_session:request(rpc.imports)) do
            ui.import:addTopLevelItem(q.QTreeWidgetItem{hex(r.FirstThunk), r.Name, childs = r.childs})
        end
        ui.import:expandAll()
    end)
end)

ucmd.register('.download-pdb', function(argv)
    local name = assert(argv[1])
    local list = g_session << function()
        local res = table {}
        local symdir = assert(__config.symbol_cache)
        for m in name == '*' and udbg.target:enum_module() or require 'pl.seq'.list{udbg.target:get_module(name)} do
            local sig = m 'pdb_sig'
            if sig then
                local pdbname = m'pdb_path' and os.path.basename(m'pdb_path') or os.path.withext(m.name, 'pdb')
                res:insert {
                    base = m.base,
                    symdir = os.path.join(symdir, pdbname, sig), pdbname = pdbname, sig = sig
                }
            else
                log.warn(m.name, 'have not pdbinfo')
            end
        end
        return res
    end

    thread.spawn(function()
        table.imap(function(t)
            local url = 'https://msdl.microsoft.com/download/symbols/' .. t.pdbname .. '/' .. t.sig .. '/' .. t.pdbname
            local pdbpath = os.path.join(t.symdir, t.pdbname)
            if os.path.exists(pdbpath) then
                log.info('[skip]', pdbpath)
            else
                local fmt = 'Invoke-WebRequest %s -OutFile "%s"'
                local cmd = fmt:format(url, pdbpath)
                os.mkdirs(t.symdir)
                log('[cmd]', cmd)
                local status, code = os.execute('powershell -Command "' .. cmd .. '"')
                if status and code == "exit" then
                    log('success', cmd)
                    g_session(function()
                        get_module(t.base):load_symbol(pdbpath)
                    end)
                else
                    log.error(status, code)
                end
            end
        end, list)
        log.info('[download-pdb]', 'done')
    end)
end)

uevent.on.clientUiInited = function()
    local ui = g_client.ui
    qt.gui(function()
        local a = q.QAction {
            setText = 'PE View',
            ['triggered()'] = function()
                local base = qt.metaCall(ui.main:focusWidget(), 'getCell(QString)', qt.QString'Base')
                if base and not base:isEmpty() then
                    g_client.service.clientCommand{'.pe-view '..base:toStdString()}
                end
            end,
        }
        ui.module:addAction(a)
        ui.memoryLayout:addAction(a)

        ui.module:addAction(q.QAction {
            setText = 'Download PDB',
            ['triggered()'] = function()
                local name = qt.metaCall(ui.module, 'getCell(int)', 0)
                if name and not name:isEmpty() then
                    g_client.service.clientCommand{'.download-pdb '..name:toStdString()}
                end
            end,
        })
    end)
end