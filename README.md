<p align="center"><img src="docs/icon.png" width="128" alt="DockLock icon"></p>

<h1 align="center">DockLock</h1>

<p align="center">把 macOS 程序坞（Dock）锁定在你指定的显示器上 —— 开源、免费的 DockLock Pro / Plus / Lite 替代品。<br>
Keep the macOS Dock on the displays you choose — an open-source replacement for DockLock Pro / Plus / Lite.</p>

<p align="center">
  <a href="https://github.com/yihui-dev/docklock-yihui/actions/workflows/build.yml"><img src="https://github.com/yihui-dev/docklock-yihui/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <a href="https://github.com/yihui-dev/docklock-yihui/releases"><img src="https://img.shields.io/github/v/release/yihui-dev/docklock-yihui?include_prereleases" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple" alt="macOS 13+">
</p>

---

## 解决什么问题

多显示器下，只要鼠标碰到另一台显示器的底边，macOS 就会把程序坞“搬”过去。写代码、看视频、共享屏幕时程序坞到处乱跳非常烦人。

DockLock 的做法与 DockLock Lite/Plus 相同，**不修改系统文件、不需要关闭 SIP**：
它用一个事件监听（CGEventTap，需要“辅助功能”权限）让鼠标在**不允许放置程序坞的显示器**上始终离底边 2–3 个像素。macOS 只有在鼠标“顶住”屏幕最底下那一行像素时才会搬动程序坞，所以程序坞再也跳不过去；而鼠标在显示器之间正常穿行不受任何影响（上下堆叠的显示器之间的“通道”不会被挡住）。

## 功能对照

| 功能 | DockLock Lite | DockLock Plus | DockLock Pro（计划中） | **本应用** |
|---|:-:|:-:|:-:|:-:|
| 把程序坞锁定在指定显示器（可多选“允许的显示器”） | ✓ | ✓ | ✓ | ✓ |
| 阻止程序坞在显示器之间乱跳 | ✓ | ✓ | ✓ | ✓ |
| 每种显示器组合分别记住设置（笔记本合盖/开盖、办公室/家里） | ✓ | ✓ | ✓ | ✓ |
| 睡眠唤醒、插拔显示器后自动把程序坞移回来（等鼠标静止后） | ✓ | ✓ | ✓ | ✓ |
| 开会/共享屏幕时隐藏程序坞 | ✓ | ✓ | ✓ | ✓ 另可**自动检测屏幕共享**和会议应用 |
| 按住修饰键（⇧/⌘/⌥/⌃ 及组合）时临时允许程序坞跳转 | 付费 | ✓ | ✓ | ✓ |
| 隐藏菜单栏图标 / 隐藏 Dock 图标 / 开机启动 | 付费 | ✓ | ✓ | ✓ |
| 程序坞跟随鼠标 | – | ✓ | ✓ | ✓ |
| 程序坞跟随活动窗口 | – | ✓ | ✓ | ✓ |
| 程序坞跟随当前应用（可为每个应用指定显示器/忽略） | – | ✓ | ✓ | ✓ |
| 菜单中“把程序坞移到某台显示器 / 左右上下” | – | ✓ | ✓ | ✓ |
| Apple 快捷指令 / Siri（22 个动作） | – | ✓ | ✓ | ✓ 全部 22 个 + 额外动作 |
| URL Scheme | – | `DockLockPlus://` | ✓ | `docklock://`，**兼容** `DockLockPlus://` |
| 命令行 CLI | – | ✓ | ✓ | ✓ 语法兼容 |
| Raycast | – | 扩展 | ✓ | Script Commands（`Integrations/raycast`） |
| 全局快捷键移动程序坞 | – | 需借助快捷指令 | ✓ | ✓ 内置 |
| 暂停锁定（5 分钟/15 分钟/1 小时/手动恢复） | – | – | – | ✓ |
| 保留触发角（Hot Corners） | – | – | – | ✓ |
| 竖直程序坞（左/右） | – | – | ✓ | 部分：边缘防护同样支持左/右边缘 |

## 安装

### 方式一：下载编译好的版本
从 [Releases](https://github.com/yihui-dev/docklock-yihui/releases) 下载 `DockLock.dmg` 或 `DockLock.zip`（附 `SHA256SUMS.txt` 校验和）；最新的开发版构建在 **Actions → Build** 的产物里。
应用是 ad-hoc 签名的，第一次打开请在 Finder 里**右键 → 打开**，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/DockLock.app
```

### 方式二：自己编译（需要 Xcode 15+，macOS 13+）

```bash
git clone https://github.com/yihui-dev/docklock-yihui.git
cd docklock-yihui
open DockLock.xcodeproj        # 在 Xcode 中 ⌘R 运行
# 或者命令行编译并安装到 /Applications：
Scripts/build.sh --install
```

`DockLock.xcodeproj` 由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 根据 `project.yml` 生成，修改工程配置后运行 `xcodegen generate` 即可。

## 首次使用

1. 打开 DockLock，按提示在 **系统设置 › 隐私与安全性 › 辅助功能** 中打开 DockLock（列表里没有就点 **+** 添加）。
2. 确认 **系统设置 › 桌面与程序坞 › “显示器具有单独的空间”** 已打开（macOS 默认打开；修改后需注销）。
3. 在菜单栏图标 → **允许程序坞出现在** 中勾选想放程序坞的显示器（默认只允许当前程序坞所在的那台）。完成！

> 每次重新编译/更新后，macOS 可能沿用旧的辅助功能授权导致失效：在辅助功能列表里把 DockLock 删掉再重新添加即可。

## 使用说明

- **锁定模式**：程序坞只会出现在“允许”的显示器上。一台都不勾选 = 在所有显示器上隐藏程序坞（建议配合“自动隐藏”）。
- **跟随鼠标 / 跟随活动窗口 / 跟随当前应用**：程序坞会在“允许”的显示器之间自动移动。在 *设置 › 自动化* 里可以为某个应用指定固定显示器或让它被忽略。
- **手动移动**：菜单“把程序坞移到…”、快捷键、快捷指令、URL、CLI 都可以；在锁定模式下，程序坞会被**固定**在你选的显示器上，直到显示器布局变化或你点“解除固定”。
- **修饰键**：在 *设置 › 通用* 选择按住哪些键时允许程序坞像平常一样跳转（例如 ⌥⌘）。
- **隐藏程序坞（开会模式）**：菜单“在所有显示器上隐藏程序坞”，或在 *设置 › 隐藏程序坞* 里设置“屏幕共享/录屏时”或“某些会议应用运行时”自动隐藏；可选在隐藏期间临时开启系统的“自动隐藏”，结束后恢复。
- **自动移回**：睡眠唤醒、插拔显示器后，如果程序坞落在了不允许的显示器上，DockLock 会在**鼠标静止**一小会儿后（可调，默认 1.5 秒）把它移回来；菜单打开时不会动。

### 关于“自动移动程序坞”的说明

macOS 没有公开的“把程序坞移到某显示器”接口，只有真实的鼠标“顶住底边”才会触发。DockLock 移动程序坞时，会在你不用鼠标的间隙（且没有菜单打开时）把鼠标短暂移到目标显示器底边，通过 **IOKit HID 系统注入相对位移**（与真实鼠标走同一条路径）完成“顶住”动作，然后把鼠标放回原处；它会**读取程序坞的实际位置来确认是否成功**，失败时再尝试 CGEvent 方式，并记住在你这台 Mac 上有效的方式。

CI 中的端到端测试（macOS 15.7，两台显示器）已验证：边缘防护能把鼠标挡在底边之外、自动移动与“跟随鼠标”都能把程序坞移到另一台显示器。

如果将来某个 macOS 版本拒绝了自动移动，DockLock 会在目标显示器上显示提示，而此时其它显示器的底边都已被挡住 —— 你只要把鼠标往目标显示器底边推一下，程序坞就只能去那里。**阻止程序坞乱跳（核心功能）不依赖自动移动，始终有效。**

## 自动化

### URL Scheme（兼容 DockLock Plus）

```
docklock://enableDockLock                    docklock://disableDockLock        docklock://toggleDockLock
docklock://enableDockFollowsMouse            docklock://disableDockFollowsMouse
docklock://enableDockFollowsActiveWindow     docklock://disableDockFollowsActiveWindow
docklock://enableDockFollowsApps             docklock://disableDockFollowsApps
docklock://moveDockUp | moveDockDown | moveDockLeft | moveDockRight
docklock://moveToDisplay?name=Studio         docklock://moveToDisplay?x=1920&y=200
docklock://enableDockLockOnDisplay?name=Studio      （允许）
docklock://disableDockLockOnDisplay?x=0&y=0         （禁止）
docklock://setMode?mode=lock-selected|follows-mouse|follows-window|follows-apps|disabled
docklock://hideDock   docklock://showDock   docklock://toggleHideDock
docklock://pause?minutes=15   docklock://resume   docklock://moveDockHome   docklock://moveDockToPointer
docklock://settings   docklock://restartDock   docklock://quit
```

所有 `DockLockPlus://…` 链接同样有效，原有的自动化无需修改。坐标以主显示器左上角为 (0,0)，`x=1&y=1` 即主显示器。

### 命令行（语法兼容 DockLock Plus CLI）

```bash
Scripts/install-cli.sh            # 创建 /usr/local/bin/docklock
docklock status                   # 状态、显示器、程序坞位置
docklock displays                 # * = 程序坞所在, + = 允许, h = 默认
docklock mode follows-mouse       # lock-selected | follows-mouse | follows-apps | follows-window | disabled
docklock move left                # left | right | up | down
docklock move 1920 200            # 按坐标
docklock move "Studio Display"    # 按名称（也支持 UUID、#2、main、builtin）
docklock allow --display "Studio Display" on
docklock allow --xy 1 1 off
docklock hide on | off | toggle
docklock pause 15 ; docklock resume
docklock launch ; docklock quit
docklock status --json
```

退出码：`0` 成功，`1` 用法错误，`2` 命令失败，`3` DockLock 未运行，`4` 通信错误。

### Apple 快捷指令 / Siri

在“快捷指令”App 中搜索 **DockLock**：启用/停用 DockLock、启用/停用/查询 跟随鼠标·跟随活动窗口·跟随当前应用、启动/退出、移动程序坞到显示器（名称/方向/坐标/鼠标所在）、获取程序坞所在显示器、允许/禁止显示器（名称/坐标）、隐藏程序坞、移回默认显示器。可配合“自动化 → App 打开/关闭”实现会议时自动隐藏。

### Raycast

把 `Integrations/raycast` 目录添加到 Raycast 的 *Script Commands* 即可。

## 常见问题

- **程序坞还是会跳？** 检查菜单栏图标是否有 ⚠︎（未授权辅助功能），以及“显示器具有单独的空间”是否打开。
- **上下堆叠的显示器**：上方显示器与下方显示器相接的那一段底边是鼠标穿行的通道，不会被挡住（macOS 也无法在那里唤出程序坞），两侧伸出的部分照常受保护。
- **触发角**：默认保留；鼠标到达角落后有 0.3 秒宽限，可在“高级”中调整或关闭。
- **Cmd+Tab 切换器** 总是出现在程序坞所在的显示器上，这是系统行为。
- **与 DockLock Lite/Plus 同时运行** 会互相冲突，DockLock 启动时会提示你退出它们。
- **隐私**：不联网、不收集任何数据；只使用“辅助功能”权限来避开/移动程序坞。

## 开发

```
App/Sources/            macOS 应用（AppKit + SwiftUI）
  System/               事件监听、程序坞检测与移动、快捷键、CLI 通道
  UI/                   菜单栏、设置窗口、提示浮层
  Intents/              App Intents（快捷指令 / Siri）
DockLockCore/           与平台无关的核心逻辑（几何、策略、URL/CLI 解析、设置）+ 单元测试
Integrations/raycast/   Raycast Script Commands
Scripts/                编译、安装 CLI、生成图标
```

```bash
swift test --package-path DockLockCore   # 核心逻辑单元测试（macOS / Linux 均可）
python3 Scripts/check_localization.py    # 检查所有界面文字都有中文翻译
```

GitHub Actions 会在 macOS 上运行单元测试、编译应用、做冒烟测试（启动应用并通过 CLI 操作），再用 `Tests/E2E` 创建一台**虚拟第二显示器**做端到端测试（鼠标被挡在受保护显示器的底边之外、允许的显示器不受影响、隐藏模式、自动移动程序坞、跟随鼠标），最后打包 zip/dmg。

---

## English

DockLock stops the macOS Dock from jumping between displays. Like the commercial DockLock apps it uses an
Accessibility event tap that keeps the pointer a couple of points away from the Dock edge of every display the
Dock is **not** allowed on, so macOS never receives the "push against the edge" that moves the Dock — no system
files are touched and SIP stays on.

Everything DockLock Lite and Plus offer is here — allowed displays remembered per display arrangement, automatic
return after sleep/display changes, hiding the Dock for meetings (plus automatic screen-sharing detection),
modifier-key override, follow mouse / active window / apps, move-to-display menu actions, 22 Shortcuts actions,
a `docklock://` URL scheme that also accepts `DockLockPlus://` URLs, a compatible CLI and Raycast script
commands — plus built-in global hot keys, pausing and hot-corner support. Requires macOS 13 or later.

Build with Xcode (`open DockLock.xcodeproj`) or `Scripts/build.sh --install`, grant Accessibility access, and pick
the allowed displays from the menu bar icon.

## 参与贡献

欢迎 Issue 和 PR！请先阅读 [贡献指南](CONTRIBUTING.md) 和 [行为准则](CODE_OF_CONDUCT.md)；原理说明见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，
版本变化见 [CHANGELOG.md](CHANGELOG.md)，安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

DockLock 是独立的开源实现，与 DockLock Lite / Plus / Pro 的开发者没有关联。

## License

[MIT](LICENSE)
