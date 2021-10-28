
local mod = {}

mod.parser = [[
scan-patch
    <module>     (string)           which module

    -s, --section (optional string) specify the section
    -S, --except (optional string)  dont compare these section
]]

local function on_revert(obj)
    local tbl = obj:find 'table'
    local address = tbl:line('.', 0)
    local item = tbl.result[tonumber(address)]
    log('[patch]', 'revert', udbg.target:get_symbol(address), udbg.target:write_bytes(item.address, item.f))
end

function mod.scaner(m, opt)
    if type(m) ~= "userdata" then
        m = assert(udbg.target:get_module(m), 'module not exists')
    end

    local IMAGE_SCN_MEM_WRITE = 0x80000000
    local IMAGE_SCN_MEM_EXECUTE = 0x20000000
    local pe = PEUtil.from_file(m.path)
    local mpe = PEUtil.from_base(m.base)
    if not pe then
        error('parse ' .. m.name .. ' failed')
    end

    return coroutine.wrap(function()
        local yield = coroutine.yield
        local scount = pe('section', '#')
        local count = 0
        local base = m.base
        -- specify the section
        local section = opt.section
        -- exclude section
        local except_section = opt.except
        for i = 0, scount-1 do
            local section_count = 0
            local name, va, size, ch = pe('section', i)
            local executable = ch & IMAGE_SCN_MEM_EXECUTE > 0
            if ch & IMAGE_SCN_MEM_WRITE == 0 and executable then
                -- log(name, va, size, ch & IMAGE_SCN_MEM_WRITE)
                if section and name ~= section then goto continue end
                if except_section and name:find(except_section) then
                    ui.warn('----------------------', 'skip', m.name, name, hex(m.base+va), '----------------------')
                    goto continue
                end
                local mdata
                for off, len in pe:compare_section(mpe, i) do
                    if section_count == 0 then
                        mdata = mpe:read_data(va, size)
                    end
                    local a = base + va + off
                    yield {
                        f = pe:read_data(va + off, len),
                        m = mdata:sub(off+1, off+len),
                        offset = va + off,
                        address = a,
                        length = len,
                        section = name,
                    }
                    count = count + 1
                    section_count = section_count + 1
                end
                if section_count > 0 then
                    ui.warn('section count', section_count)
                end
                ::continue::
            end
        end
        if count > 0 then ui.warn('total count', count) end

        -- scan export hook
        local tempe, exp
        for i in pe:compare_export(mpe) do
            if not tempe then
                tempe = require 'pefile'.FromAddress(base)
                exp = tempe.ExportDirectory
            end
            local info = tempe:GetExportInfo(i, exp)
            -- ui.info('export hook', i, info.Name, info.Address, get_symbol(info.Address))
            info.Name = m.name..'!'..info.Name
            yield {
                address = exp.AddressOfFunctions + i * 4 + base,
                length = 4,
                export = info,
            }
        end
    end)
end

function mod.on_view(vbox)
    local hbox = table.search_item(vbox, 'name', 'bottom_hbox')
    hbox.childs:insert(2, ui.button {title = '&Revert', on_click = on_revert})
end

mod.column = {
    {label = 'Address', width = 12},
    {label = 'Symbol', width = 20},
    {label = 'Size', width = 5},
    {label = 'Origin', width = 20},
    {label = 'Patched', width = 20},
    {label = 'Disasm', width = 30},
}

function mod.main(args, out)
    local result = {}
    if out.tbl then
        out.tbl.result = result
    end

    local target = assert(udbg.target)
    local function output(cs, item)
        local exp = item.export
        if exp then
            out(hex(item.address), exp.Name, 4, '<export>', target:get_symbol(exp.Address))
        else
            result[item.address] = item
            out(hex(item.address), target:get_symbol(item.address), item.length, item.f:tohex(), item.m:tohex(), cs:disasm(item.address, target)[1].string)
        end
    end

    local list = target:module_list(args.module)
    require 'udbg.task'.spawn(function(task)
        for i, m in ipairs(list) do
            local cs = Capstone.new(m.arch)
            log('[scan-patch]', m.name, m.path)
            local ok, err = pcall(function()
                for item in mod.scaner(m, args) do
                    output(cs, item)
                end
            end)
            if not ok then
                ui.error('[scan-patch]', m.name, err)
            end
            out.progress = i / #list * 100
        end
    end)
end

return mod