---
name: jimmer-migrations
description: |
  Database migration workflow for Jimmer entity changes with type mapping, FK/index rules, logical-delete columns, and annotation-to-constraint alignment.
triggers:
  - "Jimmer migration"
  - "Liquibase"
  - "Flyway"
  - "@KeyUniqueConstraint"
  - "@OnDissociate"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Jimmer Migrations

Use for Liquibase/Flyway migrations aligned with Jimmer entity changes.

## Workflow

1. Detect migration setup:

```bash
scripts/next-migration.sh /path/to/project
```

2. Read entity annotations and existing migrations.
3. Follow existing migration format and naming exactly.
4. Add Liquibase file to master changelog when project uses one.
5. Compile:

```bash
scripts/compile.sh /path/to/project
```

## DDL Compiler — generated schema from entities

Jimmer ships a compile-time DDL generator (`jimmer-ddl-compiler` as an extra KSP/APT processor). Use it when the project wants schema SQL derived from the entity model instead of hand-written; always review generated SQL before applying.

- Enable: add the processor + `jimmerDdl.*` args (`enabled`, `databaseType` e.g. `postgresql`, `outputFormat` `flyway`|`plain`, `outputDir`, `version`, `description`).
- Incremental: a snapshot file (`.jimmer-ddl/entity-table-snapshot.properties`) records table hashes — later builds emit diff SQL and detect `@Table(name=...)` renames. With JDBC settings and `compareDatabase`, it diffs against the live schema instead.
- Scope knobs: `includePackages`/`excludePackages`, `includeForeignKeys`/`includeIndexes`/`includeSequences`/`includeManyToManyTables`; `profiles` generate for several dialects in one build.
- In projects with an established hand-written migration flow, the generator is a draft source, not a replacement — the reviewed migration file stays the source of truth.

## Type Mapping

| Java/Kotlin | PostgreSQL | MySQL |
|---|---|---|
| `UUID` | `uuid` | `char(36)` |
| `String` | `varchar(255)` | `varchar(255)` |
| `Int` / `Integer` | `integer` | `int` |
| `Long` | `bigint` | `bigint` |
| `Boolean` | `boolean` | `tinyint(1)` |
| `Instant` | `timestamptz` | `timestamp` |
| `LocalDateTime` | `timestamp` | `timestamp` |
| `LocalDate` | `date` | `date` |
| `BigDecimal` | `numeric(19,4)` | `decimal(19,4)` |
| Enum | `varchar(50)` | `varchar(50)` |
| `@Serialized` | `jsonb` | `json` |

## Annotation Alignment

| Jimmer annotation | DB constraint |
|---|---|
| `@OnDissociate(DELETE)` | `ON DELETE CASCADE` |
| `@OnDissociate(SET_NULL)` | `ON DELETE SET NULL`, column nullable |
| `@Key` | unique constraint on key columns (one constraint per `group`) |
| `@KeyUniqueConstraint` | DB unique constraint required; include logical-delete flag column when entity has `@LogicalDeleted`; `isNullNotDistinct = true` -> `UNIQUE NULLS NOT DISTINCT` (Postgres) |
| `@Version` | integer not null default 0 |
| `@LogicalDeleted` | flag column: boolean not null default false / nullable timestamp / etc. |
| `@OneToOne @JoinColumn` | FK plus unique when truly one-to-one |
| `@MapsId` | PK column doubles as FK — no separate FK column |
| `@JoinColumn(foreignKeyType = FAKE)` | no FK constraint on purpose — do not add one |

## Index Rules

- Index every FK column unless covered by stronger index.
- `@ManyToOne` FK -> index.
- inverse `@OneToMany` FK -> index on child table.
- many-to-many join table -> indexes for both directions.
- unique constraint for `@Key` usually replaces extra same-column index.
- partial index (`WHERE deleted_at IS NULL`) when combining unique keys with timestamp-based logical delete on Postgres — only if `@KeyUniqueConstraint` is not used for SQL upserts.

## Safety

- Do not drop/rename columns without explicit user confirmation.
- Do not generate irreversible data migrations from guesses.
- DB constraint must match Jimmer dissociation/key annotations.
