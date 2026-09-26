# Changelog

本文件记录所有用户可见的变化，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [1.0.0] - 2026-09-26

首个版本，完整替代 DockLock Lite / Plus。

### Added
- 边缘防护：让鼠标避开“不允许”显示器的程序坞边缘，程序坞不再在显示器之间乱跳；显示器之间的通道不受影响。
- 每种显示器组合分别记住允许的显示器；睡眠唤醒、插拔显示器后自动把程序坞移回（等待鼠标静止，经 IOKit HID 注入并验证结果）。
- 模式：锁定、跟随鼠标、跟随活动窗口、跟随当前应用（可按应用指定显示器或忽略）。
- 按住修饰键临时允许程序坞跳转；暂停锁定；保留触发角。
- 隐藏程序坞（开会模式），可在屏幕共享 / 录屏或会议应用运行时自动隐藏。
- `docklock://` URL Scheme（兼容 `DockLockPlus://`）、兼容 DockLock Plus 的命令行、22+ 个快捷指令动作、全局快捷键、Raycast 脚本命令。
- 简体中文界面。
- 贡献指南、行为准则、安全政策、Issue / PR 模板；CI 覆盖单元测试、翻译完整性、冒烟测试和虚拟第二显示器端到端测试。

[Unreleased]: https://github.com/yihui-dev/docklock-yihui/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yihui-dev/docklock-yihui/releases/tag/v1.0.0
