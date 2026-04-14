# Jimmer AI Toolkit

A comprehensive set of instruction files, commands, and MCP tools that turn AI coding assistants (Claude Code, Qwen Code, GigaCode) into Jimmer ORM experts.

## What's Included

### Instruction Files (`instructions/`)
Core Jimmer knowledge — always loaded into AI context:
- **Entity design** — interface-based entities, associations, annotations, @Key, @OnDissociate
- **Save modes** — SaveMode, AssociatedSaveMode, save result handling
- **Repository patterns** — KRepository/JRepository, saveCommand, anti-patterns
- **Fetchers & Generated Code** — Fetcher API, View vs Fetcher decision, N+1 prevention, generated classes
- **DTO language** — complete .dto syntax reference (all operators, specification QBE, enum mapping)

Optional (enabled via flags):
- **Kotlin** — Kotlin-specific Jimmer patterns
- **Quarkus** — Quarkus integration reference

### Commands (`commands/`)
Interactive workflows triggered by slash commands:
- `/jimmer-entity` — design a new entity with repository
- `/jimmer-dto` — generate .dto file (Views, Inputs, Specifications)
- `/jimmer-build-query` — build typed queries, aggregates, window functions
- `/jimmer-migration` — generate database migration (Liquibase/Flyway)
- `/jimmer-debug` — diagnose Jimmer errors with full error catalog

### MCP Server (`mcp/jimmer-docs-mcp/`)
- `jimmer_docs_search` — search and fetch content from official Jimmer documentation
- `jimmer_github_search` — search GitHub issues and discussions for edge cases

## Prerequisites

- **Git** — target project must be a git repository
- **Node.js 18+** — required only if using `--mcp` flag
- **Claude Code**, **Qwen Code**, or **GigaCode**

## Installation

```bash
chmod +x install.sh                                     # grant execute permission (once)
./install.sh /path/to/project                           # Java + Spring Boot (default)
./install.sh --kotlin /path/to/project                  # add Kotlin reference
./install.sh --quarkus /path/to/project                 # add Quarkus reference
./install.sh --kotlin --quarkus /path/to/project        # both
./install.sh --mcp /path/to/project                     # with MCP server
./install.sh --tool qwen /path/to/project               # Qwen Code
./install.sh --tool gigacode /path/to/project           # GigaCode
```

### Options

```
./install.sh [OPTIONS] /path/to/project

  --tool claude|qwen|gigacode       Target CLI tool (default: claude)
  --kotlin                          Add Kotlin reference to context
  --quarkus                         Add Quarkus reference to context
  --symlink                         Use symlinks instead of copies
  --mcp                             Install MCP server
```

Safe to re-run on existing projects: skips identical files, appends missing imports, never overwrites unrelated configs.

### MCP Setup

Build the bundle once before installing:

```bash
cd mcp/jimmer-docs-mcp
npm install
npm run bundle
```

Then install:

```bash
./install.sh --mcp /path/to/project
```

For GitHub issue search, create a [personal access token](https://github.com/settings/tokens) with scopes `public_repo` and `read:discussion`:

```bash
export GITHUB_TOKEN=ghp_your_token_here
```

### What Gets Installed

| Component | Claude Code | Qwen Code | GigaCode |
|---|---|---|---|
| Instructions | `.claude/*.md` | `.qwen/*.md` | `.gigacode/*.md` |
| Commands | `.claude/commands/*.md` | `.qwen/commands/*.md` | `.gigacode/commands/*.md` |
| Entry file | `CLAUDE.md` | `QWEN.md` | `GIGACODE.md` |
| MCP (`--mcp`) | `.mcp.json` | `.qwen/settings.json` | `.gigacode/settings.json` |

## Compatibility

- **Jimmer:** 0.9.x (recommended 0.9.120) — 0.10.x
- **Languages:** Kotlin and Java
- **Frameworks:** Spring Boot, Quarkus
- **AI Tools:** Claude Code, Qwen Code, GigaCode
