
return function()
    local udbg_event = {
        'bp_process_entry',
        'bp_module_entry',
        'pause_thread_create',
        'pause_thread_exit',
        'pause_module_load',
        'pause_module_unload',
        'pause_process_create',
        'pause_process_exit',
        'print_exception',
        'ignore_initbp',
        'ignore_all_exception',
    }

    for i, e in ipairs(udbg_event) do
        udbg_event[i] = ui.checkbox {title = e, name = e, checked = __config[e]}
    end
    table.insert(udbg_event, 'stretch')

    local dlg = ui.dialog {
        title = 'Option', parent = true,
        minimumSize = {width = 300, height = 500};

        ui.groupbox {
            name = 'Events',
            -- layout = 'vbox',
            -- title = 'Event',
            table.unpack(udbg_event),
        },

        ui.buttonbox {
            'save', 'cancel',
            on_accept = function(self)
                local data = self:find 'Events':get 'ALL_VALUE'
                table.update(__config, data)
                self._root 'close'
            end,
            on_reject = function(self)
            end
        },
    }
    dlg 'exec'
end