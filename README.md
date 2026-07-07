# Jimmer AI Toolkit

Skills-native toolkit that helps AI coding agents work with Jimmer ORM without keeping large context files always loaded.

## What's Included

### Skills (`skills/`)

Task skills:
- `jimmer-entity` — entity creation/change workflow with interface, association, key, base type, and repository rules
- `jimmer-dto` — `.dto` workflow and syntax for Views, Inputs, Specifications, input handle modes, fold/flat, aliases, and configurations
- `jimmer-query` — typed query workflow for filters, pagination, `TABLE_EX`, aggregates, typed tuples, base tables, and bulk operations
- `jimmer-migrations` — Liquibase/Flyway migrations aligned with Jimmer annotations and DB constraints
- `jimmer-debug` — diagnosis workflow for save, dissociation, key, loading, optimistic lock, and query errors

Reference skills:
- `jimmer-repositories` — repository/service boundaries, built-ins, and `saveCommand` return patterns
- `jimmer-fetchers` — Fetcher API, generated code, View-vs-Fetcher decisions, and N+1 batch loading
- `jimmer-save-modes` — `SaveMode`, `AssociatedSaveMode`, key matching, upsert masks, save command options, `QueryReason`
- `jimmer-advanced-mappings` — `@Formula`, `@IdView`, `@ManyToManyView`, `@LogicalDeleted`, `@Embeddable`, `@Serialized`, `@MapsId`, transient resolvers
- `jimmer-kotlin` — Kotlin entity/query/save/KSP patterns
- `jimmer-quarkus` — Quarkus dependencies, CDI/JAX-RS layers, config

### Skill Scripts

Scripts live inside the skills that use them:
- `jimmer-entity/scripts/` — project scan + compile helpers
- `jimmer-query/scripts/` — project scan + compile helpers
- `jimmer-dto/scripts/` — compile helper
- `jimmer-debug/scripts/` — compile helper
- `jimmer-migrations/scripts/` — migration discovery + compile helpers

### MCP Server (`mcp/jimmer-docs-mcp/`)

- `jimmer_docs_search` — search and fetch content from official Jimmer documentation

## Prerequisites

- Node.js 18+ — required only when using `--mcp`
- Agent CLI with skills support: OpenCode by default, or Claude Code/Qwen Code/GigaCode-compatible layout

## Installation

Skills install into the agent's **user config**, so every project can use them. Safe to run repeatedly.

```bash
chmod +x install.sh
./install.sh                    # skills only, OpenCode (default)
./install.sh --mcp              # skills + MCP docs server
./install.sh --tool claude      # install for Claude Code
./install.sh --tool claude --mcp
./install.sh --tool qwen
./install.sh --tool gigacode
```

### Options

```text
./install.sh [OPTIONS]

  --tool opencode|claude|qwen|gigacode       Target CLI tool (default: opencode)
  --symlink                                  Use symlinks instead of copies
  --mcp                                      Build and install the MCP docs server
```

With `--mcp`, the installer builds the server (`npm install && npm run bundle`) and
registers it. For Claude Code it uses `claude mcp add --scope user`; for the others it
writes the tool's config file.

## Installed Layout

Skills land in the selected tool's user-config skills directory:

| Tool       | Skills directory                |
|------------|---------------------------------|
| opencode   | `~/.config/opencode/skills/`    |
| claude     | `~/.claude/skills/`             |
| qwen       | `~/.qwen/skills/`               |
| gigacode   | `~/.gigacode/skills/`           |

```text
<skills-dir>/
  jimmer-entity/SKILL.md
  jimmer-dto/SKILL.md
  jimmer-query/SKILL.md
  jimmer-migrations/SKILL.md
  jimmer-debug/SKILL.md
  jimmer-repositories/SKILL.md
  jimmer-fetchers/SKILL.md
  jimmer-save-modes/SKILL.md
  jimmer-kotlin/SKILL.md
  jimmer-quarkus/SKILL.md
  jimmer-advanced-mappings/SKILL.md
  jimmer-entity/scripts/scan-project.sh
  jimmer-query/scripts/scan-project.sh
  jimmer-dto/scripts/compile.sh
  jimmer-migrations/scripts/next-migration.sh
  jimmer-debug/scripts/compile.sh
```

No always-loaded context imports are appended to agent entry files. Agents discover and load skills by frontmatter descriptions and triggers.

## Usage

Ask naturally:
- "Design a Jimmer entity for this domain object"
- "Generate View and Input DTOs for this entity"
- "Build a Jimmer query with filters and pagination"
- "Create migration for this entity change"
- "Diagnose this Jimmer save error"

Skills call their own local `scripts/` helpers when project discovery or compile verification is needed.

## Notes

Skill examples intentionally use abstract names such as `DomainObject`, `RelatedObject`, and `Child`. Replace them with project-specific names only when applying the pattern inside a target project.
