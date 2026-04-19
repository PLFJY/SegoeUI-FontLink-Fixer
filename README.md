# SegoeUI-FontLink-Fixer

简体中文 / [日本語](README.ja-JP.md) / [한국어](README.ko-KR.md) / [English](README.en-US.md)

> [!WARNING]
> 本项目的相当一部分代码由 AI 辅助生成，并经过持续的人工作业、联调和重构，但它仍然可能存在遗漏、边界情况处理不足或行为与预期不完全一致的问题。
> 如果你在使用过程中发现 Bug、兼容性问题、异常行为或文档缺失，欢迎积极提交 Issue。最好附上复现步骤、日志、截图和系统版本信息，这会非常有帮助。

`SegoeUI-FontLink-Fixer` 是一个偏保守、以安全为先的 PowerShell 工具，用于检查、备份、预览、应用、校验和恢复 Windows FontLink 注册表映射。

目标注册表路径：

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink`

它的主要用途是在默认 CJK 回退顺序不符合用户预期时，调整 `Segoe UI*`、`Tahoma`、`Microsoft Sans Serif` 在非中日韩系统上的字体回退优先级。

## 这是什么

这个工具不会从零重建 FontLink 列表，而是采用稳定重排策略：

- 仅把目标语言对应的字体前移
- 保留无关条目的相对顺序
- 不凭空生成当前值里不存在的条目

这意味着它更适合做“顺序修正”，而不是做激进重写。

## 安全警告

本项目会修改 `HKLM` 下的系统注册表数据，这属于敏感配置。

在使用 `apply` 或 `restore` 之前，请先阅读脚本并确认你理解风险和恢复路径。

当前实现中的关键安全行为：

- 在任何写入前，必须先完成备份
- 备份失败后不会继续执行写入
- `apply` 写入后会重新读取并校验，不通过就不会报告成功
- `restore` 会先校验备份，再额外创建一份恢复前安全备份，随后执行恢复并再次校验
- 不完整备份会被明确标记，并且不能用于恢复

这些设计可以降低风险，但不能消除风险。

## 功能

- 备份整个 `SystemLink` 键，而不是只备份 `Segoe UI*`
- 同时导出 `.reg` 文件和结构化 JSON 快照
- 写入包含哈希、时间戳、值清单的 `manifest.json`
- 自动处理所有以 `Segoe UI` 开头的注册表值
- 同时处理 `Tahoma` 和 `Microsoft Sans Serif`
- 支持 `zh-CN`、`zh-TW`、`ja-JP`、`ko-KR` 四种配置
- 支持 dry-run / 预览模式
- 支持恢复最近一个有效备份或指定路径备份
- 提供本地键盘驱动的 TUI
- 支持界面语言：
  `zh-CN`、`ja-JP`、`ko-KR`、`en-US`

## 环境要求

- Windows
- PowerShell 5.1 或更高版本
- `apply` / `restore` 需要管理员权限

## 快速开始

启动 TUI：

```powershell
.\SegoeLinker.ps1
```

也可以显式写成：

```powershell
.\SegoeLinker.ps1 tui
```

预览简体中文配置将如何调整顺序：

```powershell
.\SegoeLinker.ps1 apply zh-CN --dry-run
```

手动创建备份：

```powershell
.\SegoeLinker.ps1 backup
```

恢复最近一个有效备份：

```powershell
.\SegoeLinker.ps1 restore --latest
```

## TUI

执行 `.\SegoeLinker.ps1` 会进入本地 TUI。

TUI 设计目标是作为最终用户入口：

- 主菜单为单键操作
- 配置选择为单键操作
- 语言选择为单键操作
- 只有确实需要文本输入时才使用输入框，例如恢复指定备份路径

TUI 会把界面语言写入本地设置文件：

- `.segoelinker.user.json`

该文件保存在项目目录下，并已加入 Git 忽略。

## 界面语言

可以在 TUI 内切换语言，也可以通过命令行使用 `--lang`。

如果命令行没有显式传入 `--lang`，工具会优先使用本地缓存的界面语言设置。

示例：

```powershell
.\SegoeLinker.ps1 list --lang zh-CN
.\SegoeLinker.ps1 status --lang ja-JP
.\SegoeLinker.ps1 backup --lang ko-KR
.\SegoeLinker.ps1 tui --lang en-US
```

支持的语言 ID：

- `zh-CN`
- `ja-JP`
- `ko-KR`
- `en-US`

## 命令

```powershell
.\SegoeLinker.ps1
.\SegoeLinker.ps1 tui
.\SegoeLinker.ps1 backup
.\SegoeLinker.ps1 apply zh-CN
.\SegoeLinker.ps1 apply ja-JP --dry-run
.\SegoeLinker.ps1 restore --latest
.\SegoeLinker.ps1 restore --file .\backups\20260420-120000123
.\SegoeLinker.ps1 list
.\SegoeLinker.ps1 status
.\SegoeLinker.ps1 help
```

## 支持的配置

- `zh-CN`：优先 `Microsoft YaHei UI`、`Microsoft YaHei`
- `zh-TW`：优先 `Microsoft JhengHei UI`、`Microsoft JhengHei`
- `ja-JP`：优先 `Yu Gothic UI`、`Yu Gothic`、`Meiryo UI`、`Meiryo`
- `ko-KR`：优先 `Malgun Gothic`

配置行为刻意保持保守：

- 只移动当前值中已经存在的目标项
- 无关项保持原有相对顺序
- 不自动补不存在的字体条目

额外说明：

- `Segoe UI*`、`Tahoma`、`Microsoft Sans Serif` 都使用同一套稳定重排模型
- 只有当前值里已存在的项目会被前移
- 不会为不含 `,128,96` 条目的值凭空生成 `,128,96` 项

## 备份格式

每次备份都会在 [backups](./backups) 下创建一个带时间戳的目录。

一个完整备份包含：

- `SystemLink.reg`
  用于兼容人工检查和手工导入的完整 `reg.exe export`
- `SystemLink.snapshot.json`
  用于精确恢复逻辑的结构化完整快照
- `manifest.json`
  包含 schema 版本、时间戳、文件哈希、注册表路径和值清单

工具会在备份进行中写入 `backup.incomplete.txt`。如果备份中途失败，该目录会被保留为不可恢复状态，这是有意的安全设计。

## 恢复模型

`restore` 的设计目标是明确、保守、可验证。

执行流程：

1. 通过 `--latest` 或 `--file` 解析目标备份
2. 校验 manifest、必要文件、schema 版本、目标注册表路径和文件哈希
3. 为当前系统状态再创建一份安全备份
4. 精确恢复整个 `SystemLink` 快照
5. 再次读取注册表并校验是否与快照一致

恢复是以整个 `SystemLink` 键为单位的精确恢复：

- 备份中存在的值会被恢复
- 当前存在但备份中不存在的值会被删除

这是有意选择，因为“部分合并恢复”在这个场景里更容易引入不确定性。

## 提权

`apply` 和 `restore` 因为要写入 `HKLM`，所以必须以管理员权限运行。

脚本会在写入前检查提权状态；如果当前会话不是管理员，它会先以管理员权限重新拉起自己，再进入真正的写入流程。

提权参数传递使用了编码载荷，而不是脆弱的命令行字符串拼接，因此对空格路径、引号、Unicode 参数都更安全。

这些命令默认不强制提权：

- `backup`
- `list`
- `status`
- `apply --dry-run`
- `tui`

TUI 里的写操作同样会走这条安全的命令路径。

## 输出与校验

工具会明确输出：

- 当前提权状态
- 备份位置
- 匹配到的受管理注册表值
- 预览前后顺序差异
- 恢复时选中的备份
- 校验成功或失败结果
- 可能需要注销/重启的提醒

如果 `apply` 或 `restore` 的最终校验没有通过，工具不会声称成功。

## 会中止执行的典型情况

出现以下情况时，工具会直接停止，而不是冒险继续：

- 无效的配置 ID
- 缺失 `--file` 路径
- 备份选择无效
- 存在不完整备份标记
- 缺少 manifest、快照或 `.reg` 文件
- 备份文件哈希不匹配
- 备份目标注册表路径不匹配
- 恢复快照中包含不支持的值类型
- 目标值不是 `MultiString`
- 写入后校验不一致

## 说明

- `status` 会显示当前 `Segoe UI*`、`Tahoma`、`Microsoft Sans Serif` 的状态，以及最近一个有效备份
- `list` 会显示支持的配置和对应优先字体
- TUI 会把所选界面语言写入 `.segoelinker.user.json`
- 变更是否立即生效，取决于系统和应用；通常可能需要注销、重启，或重启相关程序
- `backups/` 除 `.gitkeep` 外已加入 Git 忽略
- `.segoelinker.user.json` 已加入 Git 忽略

## 限制

- 本工具只调整已有条目的顺序，不负责合成缺失的 FontLink 数据
- 如果 `apply` 在写入过程中中途失败，虽然前置备份已经存在，但回滚仍然是单独的显式操作
- TUI 面向本地交互控制台，不适合无人值守自动化
- 在不支持即时按键读取的环境下，TUI 会回退到按行输入兼容模式

## 免责声明

本项目尽量保守，但它仍然会修改敏感的系统注册表配置。请先理解代码和恢复路径，不要在不了解后果的情况下直接应用。
