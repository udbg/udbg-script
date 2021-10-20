
<div align="center">
    <h1>udbg</h1>
    <a href="https://discord.gg/emqz592zfT">
      <img src="https://img.shields.io/badge/chat-on%20discord-7289da.svg?style=flat-square" alt="Discord"/>
    <a href="https://t.me/joinchat/Uiww_6QfRKA1NGY1">
      <img src="https://img.shields.io/badge/chat-on%20telegram-blue.svg?style=flat-square" alt="Telegram"/>
    </a>
    <a href="https://applink.feishu.cn/client/chat/chatter/add_by_link?link_token=31as7df3-4ddb-4160-aab0-0ab00c45cd24">
      <img src="https://img.shields.io/badge/chat-on%20feishu-blue.svg?style=flat-square" alt="Telegram"/>
    </a>
    </a>
    <p><b>基于Lua的二进制调试/分析工具</b></p>
    <ul style="list-style-type: none;">
        <li><em>多种调试方式，支持远程调试</em></li>
        <li><em>丰富的脚本接口，方便扩展、定制化分析</em></li>
    </ul>
</div>

* 支持更多的调试/分析场景
  - Windows
    * 标准API调试器、VEH调试器、内核信息查看
    * [ ] WinDbg 调试引擎：可用于分析dmp、内核调试
  - 非侵入式调试、进程信息查看
  - [ ] 跨平台：支持linux、android
* 提供丰富的脚本接口，方便编写扩展、定制化分析
* 界面/核心分离，可进行远程分析/调试
* 功能抽象、分类分层，跨平台：既保留各平台的共性，降低学习成本，也允许差异化定制，实现平台特定的功能

整体上有三大功能
- **目标(进程)查看**，类似于WinDbg中非侵入式调试的概念，可以实现CE中的一部分功能，此模式下主要包含 `内存读写` `枚举模块/线程/内存页/句柄` `挂起/唤醒目标` `内存搜索` `线程堆栈回溯` 等功能
- **目标(进程)调试**，此模式下包含了**目标(进程)查看**的功能，此外还有`断点管理: 添加/删除断点，启用/禁用断点 断点Lua脚本Hook`，`调试事件循环: ` 等功能
- **动态Hook/调用**，注入进程，动态Hook，动态调用目标中的函数，类似于Frida
  - Lua动态Hook目标内任意函数 InlineHook、IATHook
  - Lua调用目标内任意函数，`libffi` `ffi`