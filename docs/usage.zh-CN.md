# DockLock 使用指南

[English](usage.md) · [README](../README.zh-CN.md)

本指南介绍 DockLock 的全部功能。如果你只是想让程序坞别再在显示器之间乱跳，看完 [快速开始](#快速开始) 就够了。

- [系统要求](#系统要求)
- [安装](#安装)
- [快速开始](#快速开始)
- [菜单栏菜单](#菜单栏菜单)
- [设置](#设置)
  - [通用](#通用) · [显示器](#显示器) · [自动化](#自动化) · [隐藏程序坞](#隐藏程序坞) · [高级](#高级)
- [常见用法](#常见用法)
- [自动化参考](#自动化参考)
  - [URL Scheme](#url-scheme) · [命令行](#命令行) · [快捷指令与 Siri](#快捷指令与-siri) · [快捷键](#快捷键) · [Raycast](#raycast)
- [故障排除](#故障排除)
- [卸载](#卸载)

---

## 系统要求

- macOS 13 Ventura 或更高版本，Apple 芯片或 Intel 均可。
- 锁定程序坞需要两台或以上显示器（“隐藏程序坞”一台也能用）。
- **系统设置 › 桌面与程序坞 › “显示器具有单独的空间”** 保持打开。这是 macOS 的默认设置，也是 macOS 唯一会在显示器之间移动程序坞的模式，所以只有这种模式下才需要锁定。

## 安装

1. 从 [Releases](https://github.com/yihui-dev/docklock-yihui/releases) 下载 `DockLock.dmg`（或 `DockLock.zip`）。**Actions › Build** 的每次运行都附带最新的开发版构建。
2. 把 **DockLock** 拖到“应用程序”文件夹。
3. 应用是临时签名的，没有经过苹果公证，所以第一次打开会被 macOS 拦住。可以右键点应用选“打开”，或者在“终端”中执行：

   ```bash
   xattr -dr com.apple.quarantine /Applications/DockLock.app
   open /Applications/DockLock.app
   ```

想自己编译的话需要 Xcode 15 或更高版本：`git clone` 后运行 `Scripts/build.sh --install`，或者用 Xcode 打开 `DockLock.xcodeproj` 按 ⌘R。

## 快速开始

1. **授予“辅助功能”权限**。第一次打开时 DockLock 会显示授权引导。点 **打开“辅助功能”设置**，在 *隐私与安全性 › 辅助功能* 里打开 **DockLock**。列表里没有的话，点 **+** 添加 `/Applications/DockLock.app`。DockLock 几秒内会自动检测到，不用重启。
2. **选择放程序坞的显示器**。点菜单栏上的 DockLock 图标，在 **允许程序坞出现在** 下面只勾选想放程序坞的那台。默认只勾选程序坞当前所在的那台。
3. 完成。把鼠标推到其他显示器的底边试试：程序坞不会再过去了。

> 原理：DockLock 让鼠标在不允许放程序坞的显示器上始终离程序坞边缘 2–3 个点。macOS 只有在鼠标顶住最后一行像素时才会搬动程序坞，所以程序坞不会再跳过去。鼠标在显示器之间正常穿行不受影响。上下堆叠的显示器相接的那段边缘是鼠标穿行的通道，不会被挡住。

## 菜单栏菜单

| 菜单项 | 作用 |
|---|---|
| 状态行 | 当前状态，例如 *程序坞已锁定 · 位于 Studio Display* |
| **启用程序坞锁定**（⌘L） | 总开关 |
| **模式 ›** | 锁定在允许的显示器上 / 跟随鼠标 / 跟随活动窗口 / 跟随当前应用 |
| **允许程序坞出现在** | 勾选程序坞可以使用的显示器。全部取消勾选，程序坞就会在所有显示器上保持隐藏 |
| **把程序坞移到 ›** | 按名称，或移到左 / 右 / 上 / 下的显示器、鼠标所在的显示器、默认显示器 |
| **解除程序坞在 … 上的固定** | 手动移动后出现，点它恢复正常锁定 |
| **在所有显示器上隐藏程序坞** | 开会 / 演示模式 |
| **暂停锁定 ›** | 5 分钟、15 分钟、1 小时，或直到手动恢复 |
| **设置…**（⌘,）· **重新启动程序坞** · **关于** · **退出** | |

菜单栏图标会显示当前状态：锁表示已锁定，箭头表示跟随中，暂停符号表示已暂停，被划掉的程序坞表示已隐藏，**!** 表示 DockLock 需要“辅助功能”权限。

## 设置

### 通用

- **状态卡片**：显示当前状态，带总开关。
- **模式**
  - **锁定在允许的显示器上**：程序坞只停留在允许的显示器上，绝不会跳到别处。
  - **程序坞跟随鼠标**：鼠标停在哪台允许的显示器上，程序坞就移过去。
  - **程序坞跟随活动窗口**：程序坞移到你正在用的窗口所在的显示器。
  - **程序坞跟随当前应用**：切换应用时，程序坞移到该应用所在的显示器，或你在 *自动化* 里给它指定的显示器。

  所有模式都只会用“显示器”页里勾选的显示器。手动移动（菜单、快捷键、快捷指令、URL、命令行）会把程序坞固定在所选显示器上，直到显示器布局发生变化。
- **按住以下按键时允许程序坞跳转**：按住这些键（比如 ⌥⌘）时，程序坞可以像平常一样移到任意显示器。如果移到了不允许的显示器，DockLock 会让它留在那里，不会再移回去。不建议只用 Shift：鼠标停在底边附近时打字，可能会误触发。
- **应用**：登录时启动、菜单栏图标、程序坞图标，以及 **语言**（跟随系统，或从 10 种语言中选择，重启 DockLock 后生效）。

  隐藏菜单栏图标后，从访达、聚焦搜索或启动台再打开一次 DockLock，就能回到设置。

### 显示器

- **布局图**：实时显示你的显示器。蓝色表示允许放程序坞，灰色表示禁止。橙色线表示受保护的边缘，小程序坞表示程序坞当前所在的位置。点显示器可以允许或禁止，右键可以选 **把程序坞移到这里**、**设为默认显示器**、**允许 / 禁止**。
- **显示器列表**：同样的开关，并带标记：*程序坞*（当前在这里）、*默认*（移回时的目标）、*主显示器*、*已固定*（手动移动后）。
- **已记住的显示器组合**：每种显示器连接组合都会单独保存允许列表，例如“只有笔记本”“笔记本 + 公司显示器”“笔记本 + 家里两台显示器”。不再用的组合可以在这里忘记。

### 自动化

- **快捷键**：全局快捷键可以：
  - 开关锁定；
  - 把程序坞移到左 / 右 / 上 / 下的显示器、鼠标所在的显示器，或移回默认显示器；
  - 隐藏程序坞；
  - 切换模式。

  默认都是关闭的。打开后，点快捷键按钮即可录制新的组合键，按 Esc 取消。
- **应用规则**：用于“跟随当前应用”和“跟随活动窗口”模式。每个应用可以选 *其窗口所在的显示器*、某台固定的显示器，或 *忽略此应用*。
- **快捷指令、URL Scheme 与命令行**：示例，以及一键拷贝安装 `docklock` 命令的按钮。

### 隐藏程序坞

- **立即在所有显示器上隐藏程序坞**：保护所有显示器的程序坞边缘，程序坞无法弹出。
- **隐藏期间开启程序坞“自动隐藏”**：常驻显示的程序坞隐藏时会一直留在屏幕上，所以隐藏期间 DockLock 会临时打开系统的“自动隐藏”，结束后恢复你原来的设置（即使 DockLock 意外退出也会恢复）。
- **自动隐藏**：
  - 屏幕共享或录屏时；
  - 指定应用运行时。预置了 Zoom、Microsoft Teams、Webex、FaceTime、腾讯会议、企业微信、钉钉、飞书 / Lark、Discord、OBS 等，也可以添加其他应用。

### 高级

- **移回程序坞**：
  - 睡眠唤醒、插拔显示器、程序坞重启后，自动把程序坞移回来；
  - 移回前要等鼠标静止多久（默认 1.5 秒），以及跟随模式的等待时间（默认 1 秒）；
  - 移动失败时显示屏幕提示和通知；
  - 查看本机上可用的移动方式。
- **边缘防护**：
  - 鼠标与边缘保持的距离（默认 3 点）；
  - 受保护的显示器上触发角照常可用：鼠标到达角落后有一小段宽限时间（默认 0.3 秒）。
- **故障排除**：重新启动程序坞、打开“辅助功能”或“显示器”设置、拷贝诊断信息、重置已学习的移动方式、重置所有设置。

## 常见用法

**程序坞只放在外接显示器上，绝不去笔记本屏幕**
只勾选外接显示器。合上笔记本盖子后是另一种显示器组合，会单独记住设置。

**出门在外放笔记本上，回到桌前放大显示器上**
不用额外设置。每种显示器组合都有自己的允许列表，在两个地方各设置一次即可。

**两台显示器，只有我想换的时候才换**
只允许一台，并把 *按住以下按键时允许程序坞跳转* 设为 ⌥⌘。需要换的时候按住 ⌥⌘ 把鼠标往下推。

**程序坞在两台显示器之间跟着我走**
两台都允许，模式选 **程序坞跟随鼠标**。需要的话在 *高级* 里调整等待时间。

**演示和屏幕共享**
在 **隐藏程序坞** 页打开 *屏幕正在共享或录制时*，或者给 **在所有显示器上隐藏 / 显示程序坞** 设一个快捷键。

**Zoom 总在左边的显示器上，程序坞也跟过去**
模式选 **程序坞跟随当前应用**，在 *自动化 › 应用* 里添加 Zoom，并选左边的显示器。

## 自动化参考

### URL Scheme

`docklock://` 链接可以在快捷指令、Raycast、Alfred、浏览器或终端 `open` 等任何地方使用。DockLock Plus 的 `DockLockPlus://` 链接也全部兼容。

| URL | 作用 |
|---|---|
| `docklock://enableDockLock` / `disableDockLock` / `toggleDockLock` | 开启 / 关闭 / 切换锁定 |
| `docklock://setMode?mode=lock-selected\|follows-mouse\|follows-window\|follows-apps\|disabled` | 设置模式 |
| `docklock://enableDockFollowsMouse` / `disableDockFollowsMouse` | 开关“跟随鼠标” |
| `docklock://enableDockFollowsActiveWindow` / `disableDockFollowsActiveWindow` | 开关“跟随活动窗口” |
| `docklock://enableDockFollowsApps` / `disableDockFollowsApps` | 开关“跟随当前应用” |
| `docklock://moveDockLeft` / `moveDockRight` / `moveDockUp` / `moveDockDown` | 移到相邻显示器 |
| `docklock://moveToDisplay?name=Studio%20Display` | 按名称移动（也支持 UUID、`#2`、`main`、`builtin`） |
| `docklock://moveToDisplay?x=1920&y=200` | 移到包含该坐标的显示器 |
| `docklock://moveDockToPointer` / `moveDockHome` | 移到鼠标所在的显示器 / 默认显示器 |
| `docklock://enableDockLockOnDisplay?name=…` / `disableDockLockOnDisplay?x=…&y=…` | 允许 / 禁止某台显示器 |
| `docklock://hideDock` / `showDock` / `toggleHideDock` | 在所有显示器上隐藏程序坞 |
| `docklock://pause?minutes=15` / `pause` / `resume` | 暂停一段时间 / 暂停到手动恢复 / 恢复 |
| `docklock://settings?tab=displays` | 打开设置（页面：`general`、`displays`、`automation`、`hideDock`、`advanced`、`about`） |
| `docklock://restartDock` / `quit` | 重启程序坞 / 退出 DockLock |

坐标单位是点，原点 0,0 在主显示器左上角（`x=1&y=1` 就是主显示器）。

### 命令行

先安装 `docklock` 命令（它是指向应用可执行文件的链接）：

```bash
Scripts/install-cli.sh        # 或：sudo ln -sf /Applications/DockLock.app/Contents/MacOS/DockLock /usr/local/bin/docklock
```

```text
docklock status [--json]            状态、显示器、程序坞位置
docklock displays [--json]          * = 程序坞所在，+ = 允许，h = 默认
docklock display                    程序坞所在显示器的名称
docklock mode [token]               查看或设置：lock-selected | follows-mouse | follows-apps | follows-window | disabled
docklock enable | disable | toggle
docklock move left|right|up|down
docklock move <x> <y>
docklock move "<显示器名称>"         也可以用 UUID、#n、main、builtin
docklock move --pointer | --home
docklock allow --display "<名称>" on|off
docklock allow --xy <x> <y> on|off
docklock hide [on|off|toggle] ; docklock show
docklock pause [分钟] ; docklock resume
docklock relocate                   立即把程序坞移回默认显示器
docklock settings | restart-dock | url <docklock://…>
docklock launch | quit | version | help
```

`move` 会等到程序坞真正移过去才返回（加 `--no-wait` 可以立即返回）。退出码：`0` 成功，`1` 用法错误，`2` 命令失败，`3` DockLock 未运行，`4` 通信错误。语法与 DockLock Plus 的 CLI 兼容，原有脚本可以直接用。

### 快捷指令与 Siri

在“快捷指令”App 中搜索 **DockLock**，可用的动作有：

- 启用、停用或查询 DockLock；
- 启用、停用或查询各个跟随模式：跟随鼠标、跟随活动窗口、跟随当前应用；
- 启动或退出 DockLock；
- 移动程序坞：按名称（可从列表选择）、移到左 / 右 / 上 / 下的相邻显示器、按坐标、或移到鼠标所在的显示器；
- 获取程序坞所在的显示器；
- 按名称或坐标允许 / 禁止某台显示器；
- 在所有显示器上隐藏或显示程序坞；
- 把程序坞移回默认显示器。

移动类动作在程序坞真正移过去后返回 **true**。可以配合 **自动化 › App**（例如打开 / 关闭 Zoom 时触发）、**专注模式**或键盘快捷键使用。

### 快捷键

设置 › 自动化 › 快捷键。默认都是 ⌃⌥⌘ 加一个键，打开后才生效：

| 功能 | 默认 |
|---|---|
| 开关锁定 | ⌃⌥⌘L |
| 移到左 / 右 / 上 / 下 | ⌃⌥⌘← / → / ↑ / ↓ |
| 移到鼠标所在的显示器 | ⌃⌥⌘D |
| 移回默认显示器 | ⌃⌥⌘H |
| 隐藏 / 显示程序坞 | ⌃⌥⌘M |
| 切换到下一个模式 | ⌃⌥⌘U |

### Raycast

在 **Raycast › Extensions › Script Commands › Add Directory** 中添加 `Integrations/raycast` 目录。添加后可以用命令把程序坞移到左 / 右 / 上 / 下、鼠标这里或默认显示器，按名称移动，开关锁定，开关隐藏，以及在跟随鼠标和锁定模式之间切换。

## 故障排除

| 问题 | 解决办法 |
|---|---|
| 程序坞还是会跳 | 看菜单栏图标上有没有 **!**（未授权“辅助功能”），确认“显示器具有单独的空间”已打开。*高级 › 边缘防护* 应显示“正在保护 N 台显示器” |
| 更新后锁定失效 | macOS 保留的是旧版本的授权。在 *隐私与安全性 › 辅助功能* 里把 DockLock 删掉再重新添加 |
| 提示“程序坞无法被唤到这台显示器上” | 那台显示器的程序坞边缘正下方紧挨着另一台显示器，macOS 无法把程序坞放在那里 |
| 没有自动移回 | 只会在鼠标静止一段时间后移动（见 *高级*），菜单打开时不会移动。如果 macOS 拒绝了自动移动，会有提示让你把鼠标往目标显示器边缘推一下 |
| 提示“DockLock Lite/Plus 正在运行” | 退出另一个应用，并从“登录项”里删掉。两个锁定工具会相互冲突 |
| Cmd+Tab 切换器出现在另一台显示器上 | 应用切换器总是跟着程序坞走，这是 macOS 的行为 |
| 其他问题 | *高级 › 拷贝诊断信息*，然后 [提交 Issue](https://github.com/yihui-dev/docklock-yihui/issues/new/choose) |

## 卸载

```bash
docklock quit                                   # 或从菜单栏退出
rm -rf /Applications/DockLock.app
defaults delete dev.yihui.docklock              # 删除设置
sudo rm -f /usr/local/bin/docklock              # 如果安装过命令行
```

最后在 **系统设置 › 隐私与安全性 › 辅助功能** 和 **登录项** 里删掉 DockLock。
