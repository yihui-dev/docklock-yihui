# 参与贡献 / Contributing

感谢你愿意改进 DockLock！中文、English 都可以。

## 报告问题

请用 [Issue 模板](../../issues/new/choose)。程序坞相关的问题和显示器布局、macOS 版本关系很大，请附上：

- macOS 版本、Mac 型号，显示器数量和排列方式（左右 / 上下）；
- DockLock 设置 › 高级 › **拷贝诊断信息** 的内容；
- 复现步骤，以及你期望的结果。

## 开发环境

- macOS 13+，Xcode 15+（CI 使用 Xcode 16）。
- 用 Xcode 打开 `DockLock.xcodeproj`，或运行 `Scripts/build.sh`。
- 工程文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成。**新增、删除或移动源文件后**请运行 `xcodegen generate` 并提交更新后的 `DockLock.xcodeproj`。
- 调试时每次重新编译都会改变签名，macOS 可能需要你在“辅助功能”里删除并重新添加 DockLock。

## 代码结构

| 目录 | 内容 |
|---|---|
| `DockLockCore/` | 与平台无关的纯逻辑（几何、防护区、策略、URL/CLI 解析、设置）。**尽量把逻辑放在这里并写单元测试。** |
| `App/Sources/System/` | 事件监听（PointerGuard）、程序坞检测（DockInspector）、自动移动（DockMover）、快捷键、CLI 通道 |
| `App/Sources/UI/` | 菜单栏、设置窗口、提示浮层 |
| `App/Sources/Intents/` | 快捷指令 / Siri（App Intents） |
| `Tests/E2E/` | CI 中用虚拟第二显示器做的端到端测试 |

原理说明见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 提交前请检查

```bash
swift test --package-path DockLockCore        # 核心单元测试（macOS / Linux 均可）
python3 Scripts/check_localization.py         # 所有界面文字都有中文翻译
Scripts/build.sh                              # 应用能编译
```

- 界面文字写英文，用 `L("…")` / `LF("…", …)` 包起来，并在 `App/Resources/zh-Hans.lproj/Localizable.strings` 中加上中文。
- 代码风格跟随周围代码：4 空格缩进，优先 `let`，注释解释“为什么”。
- 一个 PR 只做一件事；用户可见的变化请在 `CHANGELOG.md` 的 “Unreleased” 下记一笔。
- 不引入网络访问、统计或第三方依赖。

## 发布（维护者）

1. 更新 `project.yml` 中的 `MARKETING_VERSION`、`DockLockCore/Sources/DockLockCore/Basics.swift` 中的 `DockLockInfo.version`，运行 `xcodegen generate`。
2. 把 `CHANGELOG.md` 的 “Unreleased” 改为新版本号和日期。
3. 合并到 `main` 后打标签：`git tag v1.2.3 && git push origin v1.2.3`。CI 会自动构建并把 `DockLock.zip` / `DockLock.dmg` 发布到 Releases。

通过提交贡献，你同意你的代码以 [MIT 许可证](LICENSE) 发布。
