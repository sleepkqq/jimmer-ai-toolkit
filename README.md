# Jimmer AI Toolkit

A comprehensive set of instruction files, commands, and MCP tools that turn AI coding assistants (Claude Code, Qwen Code, GigaCode) into Jimmer ORM experts.

## What's Included

### Instruction Files (`instructions/`)
Core Jimmer knowledge — always loaded into AI context (~50KB):
- **Entity design** — interface-based entities, associations, annotations, @Key, @OnDissociate
- **Save modes** — SaveMode, AssociatedSaveMode, save result handling
- **Fetchers & Views** — .dto files (View/Input), Fetcher API, N+1 prevention
- **Repository patterns** — KRepository/JRepository, saveCommand, anti-patterns

### Commands (`commands/`)
Interactive workflows with full reference material built-in:
- `/jimmer-entity` — design a new entity with .dto file and repository
- `/jimmer-build-query` — build complex typed queries, @TypedTuple, DTO language reference
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
./install.sh /path/to/project                          # Claude Code (default)
./install.sh --tool qwen /path/to/project              # Qwen Code
./install.sh --tool gigacode /path/to/project           # GigaCode
./install.sh --mcp /path/to/project                    # with MCP server
```

### MCP Setup

```bash
./install.sh --mcp /path/to/project
```

For GitHub issue search, create a [personal access token](https://github.com/settings/tokens) with scopes `public_repo` and `read:discussion`:
```bash
export GITHUB_TOKEN=ghp_your_token_here
```

### Options

```bash
./install.sh [OPTIONS] /path/to/project

  --tool claude|qwen|gigacode       Target CLI tool (default: claude)
  --symlink                         Use symlinks instead of copies
  --mcp                             Install MCP server
```

Safe to re-run on existing projects: skips identical files, appends missing imports, never overwrites unrelated configs.

### What Gets Installed

| Component | Claude Code | Qwen Code | GigaCode |
|---|---|---|---|
| Instructions | `.claude/*.md` | `.qwen/*.md` | `.gigacode/*.md` |
| Skills | `.claude/commands/*.md` | `.qwen/skills/*/SKILL.md` | `.gigacode/skills/*/SKILL.md` |
| Entry file | `CLAUDE.md` | `QWEN.md` | `GIGACODE.md` |
| MCP (--mcp) | `.mcp.json` | `.mcp.json` | `.mcp.json` |

## Compatibility

- **Jimmer:** 0.9.x (recommended 0.9.120) — 0.10.x
- **Languages:** Kotlin and Java
- **Frameworks:** Spring Boot, Quarkus (framework-agnostic patterns)
- **AI Tools:** Claude Code, Qwen Code, GigaCode (first-class support)
