
local mod = {}

function mod.main()
    assert(not mod.workThread)

    mod.workThread = thread.spawn(function()
        for _, plug in ipairs(g_client.config.plugins) do
            if plug.git then
                local success, code, output
                if not os.path.exists(plug.path) then
                    os.mkdirs(plug.path)
                    success, code, output = os.spawn_child {'git', 'init', cwd = plug.path, stdout = 'pipe'}:wait_output()
                    assert(success, 'git init: '..output)
                    success, code, output = os.spawn_child {
                        'git', 'remote', 'add', 'origin', plug.git,
                        cwd = plug.path, stdout = 'pipe', stderr = 'pipe',
                    }:wait_output()
                    assert(success, 'git remote: '..output)
                end
                success, code, output = os.spawn_child {
                    'git', 'pull', '--depth=1', 'origin', plug.branch or 'master',
                    cwd = plug.path, stdout = 'pipe', stderr = 'pipe'
                }:wait_output()
                if success then
                    log('[update-plugin]', plug.name, output)
                else
                    log.error('[update-plugin]', plug.name, 'return: '..code, output)
                end
            end
        end
        mod.workThread = nil
        log('[update-plugin]', 'done.', 'Please restart to apply the change')
    end, 'plugin-update')
end

return mod