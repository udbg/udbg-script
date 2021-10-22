
<div align="center">
  <img src="https://udbg.github.io/static/image/udbg.png" width="30%">
  <h1>udbg</h1>
  <a href="https://discord.gg/emqz592zfT">
    <img src="https://img.shields.io/badge/chat-on%20discord-7289da.svg?style=flat-square" alt="Discord"/>
  </a>
  <a href="https://t.me/joinchat/Uiww_6QfRKA1NGY1">
    <img src="https://img.shields.io/badge/chat-on%20telegram-blue.svg?style=flat-square" alt="Telegram"/>
  </a>
  <a href="https://applink.feishu.cn/client/chat/chatter/add_by_link?link_token=31as7df3-4ddb-4160-aab0-0ab00c45cd24">
    <img src="https://img.shields.io/badge/chat-on%20feishu-blue.svg?style=flat-square" alt="Telegram"/>
  </a>
  <p><b>Dynamic binary analysis tools based on Lua</b></p>
  <em>Multiple debug-adaptor, support remote debugging</em><br/>
  <em>Rich script API, and easy to extend and customize</em>
</div>

Dynamic binary analysis tools based on Lua

* Support more analysis scene
  - Windows
    * Starndard API, VEH Debugger and view kernel space
    * [ ] WinDbg Engine: analyze dmp file, kernel debugging
  - Non-invasive attach
  - [ ] Cross-platform：support linux、android
* Providing rich script API, easy to extend and customize
* Separate the debugger from UI, support remote debugging: only put a few core files into remote machine, and you can control everything

Overall, there are three main functions
- **Target (process) view** like the concept 'Non-invasive attach' in windbg, this mode mainly contains functions: memory read/write, enum module/thread/memory page/handle, suspend/resume target, stack backtrace
- **Target (process) debugging** this mode contains functions in **Target (process) view**, and you can debug it, using breakpoint
- **Dynamic hook and function call** inject to target process, dynamic hook and call any function use lua in target process, like frida

*Target in udbg, commonly is process, and can be `.dmp file` or `kernel space` with other debug-adaptor*

## Download

Download the lastest zip from release page, and unzip to a new directory

* https://github.com/udbg/udbg/releases
* https://gitee.com/udbg/udbg/releases

>! Notice: DONT inclucde Non-ANSI character in the path

## Document

https://udbg.github.io/

- [Introduce](https://udbg.github.io/get_started/en/)
- [Tutorial](https://udbg.github.io/get_started/en/quick-start/tutorial.html)
- [Features](https://udbg.github.io/get_started/en/features.html)