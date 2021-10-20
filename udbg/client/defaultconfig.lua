
return [==[
---数据存放目录，默认是 `<UDBGDIR>/data`
data_dir = false

---指定其他插件/配置路径
--- plugins = {
---     {path = [[D:\Plugin1]]},
---     {path = [[D:\Plugin2]]},
--- }
plugins = {}

---指定启动编辑器的命令，默认是notepad
---如果安装了vscode，建议改为
--- edit_cmd = 'code %1'
edit_cmd = false

---远程地址映射, 配置了此项可在命令行中用键名代替对应的地址端口；
---比如配置了以下映射:
--- remote_map = {
---     ['local'] = '127.0.0.1:2333',
---     local1 = '127.0.0.1:2334',
---     local2 = '127.0.0.1:2335',
---     vmware = '192.168.1.239:2333',
--- }
---即可使用`udbg -r vmware C:\Windows\notepad.exe`进行远程调试
remote_map = {}

---是否预编译调试器端require的lua
precompile = true

---传递给调试器的配置
udbg_config = {
    ---PDB符号缓存目录
    -- symbol_cache = [[D:\Symbols]],
    ---是否忽略初始断点
    ignore_initbp = false,
    ---是否忽略所有异常
    ignore_all_exception = false,
    ---线程创建时暂停
    pause_thread_create = false,
    ---线程退出时暂停
    pause_thread_exit = false,
    ---模块加载时暂停
    pause_module_load = false,
    ---模块卸载时暂停
    pause_module_unload = false,
    ---进程创建时暂停
    pause_process_create = false,
    ---进程退出时暂停
    pause_process_exit = false,
    ---进程入口断点
    bp_process_entry = false,
    ---模块入口断点
    bp_module_entry = false,
}
]==]