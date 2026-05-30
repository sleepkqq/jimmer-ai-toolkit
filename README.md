# Jimmer AI Toolkit

Skills-native toolkit that helps AI coding agents work with Jimmer ORM without keeping large context files always loaded.

## What's Included

### Skills (`skills/`)

Task skills:
- `jimmer-entity` — entity creation/change workflow with interface, association, key, base type, and repository rules
- `jimmer-dto` — `.dto` workflow and syntax for Views, Inputs, unsafe Inputs, Specifications, aliases, and association projections
- `jimmer-query` — typed query workflow for filters, pagination, `TABLE_EX`, aggregates, typed tuples, and bulk operations
- `jimmer-migrations` — Liquibase/Flyway migrations aligned with Jimmer annotations and DB constraints
- `jimmer-debug` — diagnosis workflow for save, dissociation, key, loading, optimistic lock, and query errors

Reference skills:
- `jimmer-repositories` — repository/service boundaries, built-ins, and `saveCommand` return patterns
- `jimmer-fetchers` — Fetcher API, generated code, View-vs-Fetcher decisions, and N+1 batch loading
- `jimmer-save-modes` — `SaveMode`, `AssociatedSaveMode`, key matching, child replacement, save result handling
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

- Git — target project should be a git repository
- Node.js 18+ — required only when using `--mcp`
- Agent CLI with skills support: OpenCode by default, or Claude Code/Qwen Code/GigaCode-compatible layout

## Installation

```bash
chmod +x install.sh
./install.sh /path/to/project
./install.sh --mcp /path/to/project
./install.sh --tool claude /path/to/project
./install.sh --tool qwen /path/to/project
./install.sh --tool gigacode /path/to/project
```

### Options

```text
./install.sh [OPTIONS] /path/to/project

  --tool opencode|claude|qwen|gigacode       Target CLI tool (default: opencode)
  --symlink                                  Use symlinks instead of copies
  --mcp                                      Install MCP server config
```

## Installed Layout

Default OpenCode layout:

```text
/path/to/project/.opencode/skills/
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
