# STS2RitsuLibMod Skill

English | [中文](README.md)

A universal skill for **Slay the Spire 2 + RitsuLib** mod development, providing source code discovery, index querying, and coding assistance.

## Introduction

STS2RitsuLibMod is a Claude Code Skill that helps mod developers quickly find and reference game source code, RitsuLib APIs, and modding tutorials. Built-in indexes work out of the box without additional configuration.

## Installation

### Option 1: Clone Repository

```bash
git clone https://github.com/your-username/STS2RitsuLibModSkill.git ~/.claude/skills/STS2RitsuLibModSkill
```

### Option 2: Manual Installation

1. Download and extract this repository to Claude Code skills directory:
   - Windows: `%USERPROFILE%\.claude\skills\STS2RitsuLibModSkill\`
   - macOS/Linux: `~/.claude/skills/STS2RitsuLibModSkill/`

2. Install prerequisites:

```bash
# Windows (using winget)
winget install Microsoft.PowerShell
winget install Microsoft.DotNet.SDK.8

# macOS
brew install powershell
brew install dotnet

# Ubuntu/Debian
sudo apt-get install -y powershell dotnet-sdk-8.0
```

3. Run initialization (optional, auto-fetches RitsuLib and tutorials):

```powershell
pwsh ~/.claude/skills/STS2RitsuLibModSkill/scripts/init-skill.ps1
```

### Verify Installation

Test with this prompt in Claude Code:

> Find the implementation code for the card "Abrasive"

## Cross-Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Windows | ✅ Full Support | Auto-discover Steam, decompile DLL |
| macOS | ✅ Full Support | Auto-discover Steam, decompile DLL |
| Linux | ✅ Full Support | Auto-discover Steam, decompile DLL |

**Prerequisites**:
- Install [PowerShell Core](https://github.com/PowerShell/PowerShell) (`pwsh`)
- Install [.NET SDK](https://dotnet.microsoft.com/download) (for decompilation and project creation)

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

## Core Features

| Feature | Description |
|---------|-------------|
| **Built-in Indexes** | Pre-built indexes for game content, localization, RitsuLib API, and tutorials |
| **Auto Discovery** | Automatically locate Steam game installation and decompiled source |
| **Auto Fetch** | Automatically clone RitsuLib and tutorials from GitHub when missing |
| **Smart Query** | Fuzzy search by name, type, or keyword |
| **Dynamic Update** | Run update scripts to sync latest content |
| **Project Creation** | Create standard Mod project with NuGet template |

## Built-in Indexes

The project includes pre-built indexes (in `indexes/` directory):

| Index File | Content | Entries |
|------------|---------|---------|
| `ritsulib-api.json` | RitsuLib public types and method signatures | 1433 |
| `ritsulib-docs.json` | RitsuLib documentation titles and summaries | 23 |
| `tutorials.json` | Mod development tutorial titles and summaries | 27 |
| `sts2-content.json` | Game class names, namespaces, file paths | 3503 |
| `sts2-localization.json` | Chinese localization key-value pairs | 6805 |

## Quick Start

### User Prompt Examples

**Create a new Mod project:**
> Help me create a RitsuLib Mod project named MyMod

**Find original content reference:**
> Find the implementation code and localization text for the card "Abrasive"
> Find the implementation of the relic "Anchor"

**Find RitsuLib API:**
> How to register a new card with RitsuLib?
> Find the API for registering relics in RitsuLib

**Find tutorials:**
> Is there a tutorial for adding cards?
> How to add custom attributes to cards?

**Create game content:**
> Create a card similar to "Abrasive" that grants Strength and Thorns
> Create a new relic that draws a card at the start of each turn

**Modify original behavior:**
> I want to modify the damage of the original card "Strike", how to do it?
> Help me patch the original end-of-turn logic

## Skill Workflow

When users mention STS2 mod development, the Skill follows this workflow:

```
┌─────────────────────────────────────────────────────────────┐
│                      User Request                           │
│   "Make a card like Abrasive" / "How to register a relic?" │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   1. Initialization                         │
│   • Read global config config.json                          │
│   • Check if built-in indexes are available                 │
│   • Auto-clone RitsuLib if missing                          │
│   • Auto-clone tutorials if missing                         │
│   • Auto-decompile sts2.dll if game source missing          │
│   • Refresh stale indexes                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   2. Query Phase                            │
│   • Original content → Query sts2-content + localization    │
│   • RitsuLib → Query ritsulib-api + ritsulib-docs           │
│   • Learning → Query tutorials                              │
│   • Patching → Read target methods and callers              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   3. Coding Phase                           │
│   • Prefer RitsuLib APIs                                    │
│   • Reference tutorials and documentation                   │
│   • Use Harmony Patch when necessary                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   4. Build Verification                     │
│   • dotnet build                                            │
│   • Verify manifest depends on STS2-RitsuLib                │
│   • Ensure no game directory pollution                      │
└─────────────────────────────────────────────────────────────┘
```

## Update Indexes

When RitsuLib or tutorial repositories have updates, run:

```powershell
# Update all indexes (auto-fetches latest RitsuLib and tutorials)
pwsh -File scripts/update-indexes.ps1

# Update only RitsuLib (skip tutorials)
pwsh -File scripts/update-indexes.ps1 -SkipTutorials

# Update only tutorials (skip RitsuLib)
pwsh -File scripts/update-indexes.ps1 -SkipRitsuLib
```

## Initialize Environment

For first-time use or full update:

```powershell
# Full initialization (auto-fetch RitsuLib, tutorials, decompile game)
pwsh -File scripts/init-skill.ps1

# Skip decompilation
pwsh -File scripts/init-skill.ps1 -SkipDecompile
```

## Configuration File

Edit `config.json` in the Skill directory, shared across all projects:

```json
{
  "gameDll": "",
  "gameSourceRoot": "",
  "ritsulibRoot": "",
  "tutorialsRoot": "",
  "localizationLang": "zhs"
}
```

- Leave empty for auto-discovery
- **Auto-discovered paths are automatically saved**, no need to rediscover next time
- `localizationLang`: Localization language (zhs=Chinese Simplified, eng=English, zht=Chinese Traditional)

### Configuration Priority

```
1. Skill global config config.json
2. Cache directory
3. Auto-discovery
```

## Directory Structure

```
STS2RitsuLibModSkill/
├── README.md                          # Chinese documentation
├── README.en.md                       # English documentation
├── SKILL.md                           # Skill core documentation
├── LICENSE                            # MIT License
├── config.json                        # Global configuration
├── .gitignore
├── indexes/                           # Built-in indexes (committed to Git)
│   ├── ritsulib-api.json
│   ├── ritsulib-docs.json
│   ├── tutorials.json
│   ├── sts2-content.json
│   └── sts2-localization.json
├── scripts/                           # Scripts
│   ├── query-index.ps1               # Query indexes
│   ├── update-indexes.ps1            # Update indexes
│   ├── init-skill.ps1                # Initialize environment
│   ├── create-mod.ps1                # Create Mod project
│   ├── build-index.ps1               # Build cache indexes
│   ├── build-builtin-indexes.ps1     # Build built-in indexes
│   ├── discover-roots.ps1            # Discover paths
│   ├── acquire-ritsulib.ps1          # Fetch RitsuLib
│   ├── acquire-tutorials.ps1         # Fetch tutorials
│   └── decompile-sts2.ps1            # Decompile game
└── cache/                             # Cache directory (not committed)
```

## Trigger Conditions

The Skill activates when users mention:

- STS2 mod, RitsuLib, Slay the Spire 2 modding
- Creating cards, relics, characters, events, monsters, potions, ancients, timelines, enchantments, encounters
- Patching original game behavior
- Finding RitsuLib API or documentation

## License

This project is for mod development reference only. Decompiled source code is for local development only and is not distributed with mods.
