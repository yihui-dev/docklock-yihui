# DockLock 工作原理 / How DockLock works

[English](ARCHITECTURE.md)

## 为什么程序坞会跳

打开“显示器具有单独的空间”（macOS 默认）时，把鼠标**顶住**某台显示器程序坞所在边缘的最后一行像素，
macOS 就会把程序坞搬到那台显示器。只有真实的指针输入会触发，系统也没有公开的“把程序坞放到某台显示器”接口。

## 边缘防护（阻止乱跳）

`PointerGuard` 在独立线程上运行一个会话级 `CGEventTap`（需要“辅助功能”权限），监听鼠标移动 / 拖动事件。
`DockPolicy` 算出哪些显示器**不允许**放程序坞，`EdgeGuardPlanner` 为它们的程序坞边缘生成防护区（`ClampZone`）：

- 只防护**自由边缘**：如果边缘外紧挨着另一台显示器（上下堆叠），那一段是鼠标在两屏之间穿行的通道，绝不拦截；
- 进入防护区的事件，其位置被拉回到离边缘 `guardBand`（默认 3 点）的地方，鼠标因此到不了触发行；
  沿边缘的方向不受影响，所以横向移动很顺滑；
- 按住设置的修饰键时放行（`bypassed`），并记录下来，以便把“故意的跳转”当作手动放置；
- 触发角有短暂宽限（默认 0.3 秒），触发角功能照常可用。

每个事件只做几次比较（`PointerClampEngine`，纯逻辑、有单元测试）。没有需要防护的显示器时，事件监听会停掉。

## 程序坞在哪

`DockInspector` 通过 HIServices 的 `CoreDockGetRect`（运行时用 `dlsym` 查找，找不到时退回到程序坞的辅助功能树）读取程序坞的矩形，
`DockLocator` 按“离哪台显示器的程序坞边缘最近”判断所在显示器——自动隐藏时矩形在屏幕外也能判断。

## 自动移动程序坞

`DockMover` 模拟一次真实的“顶住边缘”：在鼠标静止、没有菜单打开、屏幕未锁定时，把鼠标移到目标显示器的自由边缘附近，
依次尝试：

1. `hid-relative-push`：通过 IOKit `IOHIDPostEvent` 注入相对位移，与真实鼠标经过同一条 HID 路径（在 macOS 15 上验证有效）；
2. `synthetic-push`：在 HID 层投递 `CGEvent` 鼠标移动事件。

每种方式都通过读取程序坞实际位置来确认，然后把鼠标放回原处；有效的方式会被记住并优先使用。
全部失败时，在目标显示器上显示提示——此时其它显示器都已被防护，用户推一下鼠标程序坞就只能去那里。

## 状态与命令

- `AppController` 是唯一的状态中心（仅主线程），菜单、快捷键、URL Scheme、CLI、快捷指令最终都执行同一个 `DockCommand`。
- 设置以 JSON 保存在 `UserDefaults`（`settings.v1`），按显示器组合（`ArrangementKey`，即所有显示器 UUID）分别保存允许列表。
- CLI 就是应用本身的可执行文件：带子命令运行时通过 `CFMessagePort`（`dev.yihui.docklock.control`）与正在运行的应用通信。

## 测试

- `DockLockCore/Tests`：几何、防护区、策略、命令解析、设置兼容性（macOS / Linux）。
- `Tests/E2E/run_e2e.sh`：CI 中创建虚拟第二显示器、授予辅助功能权限，验证防护、隐藏、自动移动与跟随鼠标。
