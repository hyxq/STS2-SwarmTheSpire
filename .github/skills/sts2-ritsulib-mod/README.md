# STS2RitsuLibMod Skill

[English](README_EN.md) | 中文

为 **Slay the Spire 2 + RitsuLib** Mod 开发提供通用的源码发现、索引查询和辅助编码能力。

## 简介

STS2RitsuLibMod 是一个 Claude Code Skill，帮助 Mod 开发者快速查找和参考游戏原版代码、RitsuLib API 以及 Mod 开发教程。内置索引开箱即用，无需额外配置即可开始查询。

## 安装

### 方式一：克隆仓库

```bash
git clone https://github.com/your-username/STS2RitsuLibModSkill.git ~/.claude/skills/STS2RitsuLibModSkill
```

### 方式二：手动安装

1. 下载本仓库并解压到 Claude Code skills 目录：
   - Windows: `%USERPROFILE%\.claude\skills\STS2RitsuLibModSkill\`
   - macOS/Linux: `~/.claude/skills/STS2RitsuLibModSkill/`

2. 安装前提条件：

```bash
# Windows (使用 winget)
winget install Microsoft.PowerShell
winget install Microsoft.DotNet.SDK.8

# macOS
brew install powershell
brew install dotnet

# Ubuntu/Debian
sudo apt-get install -y powershell dotnet-sdk-8.0
```

3. 首次使用时运行初始化（可选，会自动获取 RitsuLib 和教程）：

```powershell
pwsh ~/.claude/skills/STS2RitsuLibModSkill/scripts/init-skill.ps1
```

### 验证安装

在 Claude Code 中输入以下提示词测试：

> 帮我找一下"磨蚀"这张卡牌的实现代码

## 跨平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| Windows | ✅ 完全支持 | 自动发现 Steam、反编译 DLL |
| macOS | ✅ 完全支持 | 自动发现 Steam、反编译 DLL |
| Linux | ✅ 完全支持 | 自动发现 Steam、反编译 DLL |

**前提条件**：
- 安装 [PowerShell Core](https://github.com/PowerShell/PowerShell)（`pwsh`）
- 安装 [.NET SDK](https://dotnet.microsoft.com/download)（用于反编译和创建项目）

```bash
# macOS
brew install powershell
brew install dotnet

# Ubuntu/Debian
sudo apt-get install -y powershell
sudo apt-get install -y dotnet-sdk-8.0

# CentOS/RHEL
sudo yum install -y powershell
sudo yum install -y dotnet-sdk-8.0
```

## 核心功能

| 功能 | 说明 |
|------|------|
| **内置索引** | 预置游戏内容、本地化、RitsuLib API、教程索引，开箱即用 |
| **自动发现** | 自动定位 Steam 游戏安装目录、反编译源码 |
| **自动获取** | 缺少 RitsuLib 或教程时自动从 GitHub 克隆 |
| **智能查询** | 按名称、类型、关键词模糊查询 |
| **动态更新** | 运行更新脚本同步最新内容 |
| **项目创建** | 使用 NuGet 模板一键创建标准 Mod 项目 |

## 内置索引

项目预置以下索引（位于 `indexes/` 目录）：

| 索引文件 | 内容 | 条目数 |
|----------|------|--------|
| `ritsulib-api.json` | RitsuLib 公共类型、方法签名 | 1433 |
| `ritsulib-docs.json` | RitsuLib 文档标题、摘要 | 23 |
| `tutorials.json` | Mod 开发教程标题、摘要 | 27 |
| `sts2-content.json` | 游戏类名、命名空间、文件路径 | 3503 |
| `sts2-localization.json` | 中文本地化键值对 | 6805 |

## 快速开始

### 用户提示词示例

**创建新 Mod 项目：**
> 帮我创建一个名为 MyMod 的 RitsuLib Mod 项目

**查找原版内容参考：**
> 帮我找一下"磨蚀"这张卡牌的实现代码和本地化文本
> 查找原版遗物"Anchor"的实现

**查找 RitsuLib API：**
> RitsuLib 怎么注册一张新卡牌？
> 查找 RitsuLib 中注册遗物的 API

**查找教程：**
> 有没有添加卡牌的教程？
> 怎么给卡牌添加自定义属性？

**创建游戏内容：**
> 帮我做一张类似"磨蚀"的卡牌，效果是获得力量和荆棘
> 创建一个新遗物，效果是每回合开始抽一张牌

**修改原版行为：**
> 我想修改原版卡牌"打击"的伤害，怎么做？
> 帮我 patch 原版的回合结束逻辑

## Skill 工作流程

当用户提到 STS2 Mod 开发相关内容时，Skill 按以下流程工作：

```
┌─────────────────────────────────────────────────────────────┐
│                      用户请求                                │
│   "做一张类似磨蚀的卡牌" / "RitsuLib 怎么注册遗物？"          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   1. 初始化阶段                              │
│   • 读取全局配置 config.json                                 │
│   • 检查内置索引是否可用                                      │
│   • 缺少 RitsuLib 时自动克隆                                 │
│   • 缺少教程时自动克隆                                        │
│   • 缺少游戏源码时自动反编译 sts2.dll                         │
│   • 刷新过期索引                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   2. 查询阶段                                │
│   • 用户提到原版内容 → 查询 sts2-content + localization       │
│   • 用户提到 RitsuLib → 查询 ritsulib-api + ritsulib-docs    │
│   • 用户需要学习 → 查询 tutorials                            │
│   • 需要 Patch 时 → 读取原版方法和调用方                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   3. 编码阶段                                │
│   • 优先使用 RitsuLib API                                    │
│   • 参考教程和文档                                            │
│   • 必要时使用 Harmony Patch                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   4. 构建验证                                │
│   • dotnet build                                            │
│   • 确认 manifest 依赖 STS2-RitsuLib                        │
│   • 不污染游戏目录                                            │
└─────────────────────────────────────────────────────────────┘
```

## 更新索引

当 RitsuLib 或教程仓库有更新时，运行以下命令同步索引：

```powershell
# 更新所有索引（会自动拉取最新 RitsuLib 和教程）
pwsh -File scripts/update-indexes.ps1

# 只更新 RitsuLib（跳过教程）
pwsh -File scripts/update-indexes.ps1 -SkipTutorials

# 只更新教程（跳过 RitsuLib）
pwsh -File scripts/update-indexes.ps1 -SkipRitsuLib
```

## 初始化环境

首次使用或需要完整更新时：

```powershell
# 完整初始化（自动获取 RitsuLib、教程、反编译游戏）
pwsh -File scripts/init-skill.ps1

# 跳过反编译
pwsh -File scripts/init-skill.ps1 -SkipDecompile
```

## 配置文件

编辑 Skill 目录下的 `config.json`，所有项目共享：

```json
{
  "gameDll": "",
  "gameSourceRoot": "",
  "ritsulibRoot": "",
  "tutorialsRoot": "",
  "localizationLang": "zhs"
}
```

- 留空则自动发现
- **自动发现的结果会自动保存**，下次无需重新发现
- `localizationLang`：本地化语言（zhs=简中, eng=英文, zht=繁中）

### 配置优先级

```
1. Skill 全局配置 config.json
2. 缓存目录
3. 自动发现
```

## 目录结构

```
STS2RitsuLibModSkill/
├── README.md                          # 中文说明
├── README.en.md                       # 英文说明
├── SKILL.md                           # Skill 核心文档
├── LICENSE                            # MIT 许可证
├── config.json                        # 全局配置
├── .gitignore
├── indexes/                           # 内置索引（提交到 Git）
│   ├── ritsulib-api.json
│   ├── ritsulib-docs.json
│   ├── tutorials.json
│   ├── sts2-content.json
│   └── sts2-localization.json
├── scripts/                           # 脚本
│   ├── query-index.ps1               # 查询索引
│   ├── update-indexes.ps1            # 更新索引
│   ├── init-skill.ps1                # 初始化环境
│   ├── create-mod.ps1                # 创建 Mod 项目
│   ├── build-index.ps1               # 构建缓存索引
│   ├── build-builtin-indexes.ps1     # 构建内置索引
│   ├── discover-roots.ps1            # 发现路径
│   ├── acquire-ritsulib.ps1          # 获取 RitsuLib
│   ├── acquire-tutorials.ps1         # 获取教程
│   └── decompile-sts2.ps1            # 反编译游戏
└── cache/                             # 缓存目录（不提交）
```

## 触发条件

当用户提到以下内容时，Skill 自动激活：

- STS2 mod、RitsuLib、杀戮尖塔2模组
- 创建卡牌、遗物、角色、事件、怪物、药水、先古、时间线、附魔、遭遇
- Patch 原版游戏行为
- 查找 RitsuLib API 或文档

## 许可证

本项目仅供 Mod 开发参考使用。反编译源码仅用于本地开发，不随 Mod 分发。
