---
description: "Generate a database migration (Liquibase YAML or Flyway SQL) for Jimmer entity changes"
---

# Migration Generator

Generate database migrations aligned with Jimmer entity annotations.

## Process

1. **Scan existing project conventions FIRST:**
   - Check `application.yml` for migration tool config
   - Find existing migration files — match their format (YAML/XML/SQL), naming convention, and directory structure
   - Determine the next version number/filename from existing files
   - **Never impose a different structure on an existing project**

2. **Identify changes** — ask the user:
   - New entity, new column, new FK, new index, or modification?
   - What entity/table is affected?
   - If no existing migrations found: Liquibase (YAML) or Flyway (SQL)?

3. **Map Jimmer types to DB types:**
   - UUID → `uuid`, String → `varchar`, Instant → `timestamptz`, LocalDateTime → `timestamp`, Enum → `varchar(50)`, @Serialized → `jsonb`

4. **Align constraints with annotations:**
   - `@OnDissociate(DELETE)` → FK with `ON DELETE CASCADE`
   - `@OnDissociate(SET_NULL)` → FK with `ON DELETE SET NULL`
   - `@Key` → UNIQUE constraint on @Key columns
   - `@Version` → INTEGER column with default 0

5. **Generate indexes:**
   - All FK columns (not auto-indexed in most databases)
   - @Key columns (covered by unique constraint)
   - Columns frequently used in WHERE clauses

## Output Format

Provide:
1. Complete migration file matching the project's existing format and naming convention
2. Filename following the project's scheme
3. Include entry for master changelog if Liquibase
4. Warnings about constraint alignment

---

# Migration Reference

## Liquibase vs Flyway

| | Liquibase | Flyway |
|---|---|---|
| Format | YAML, XML, JSON, SQL | SQL, Java |
| Changelog | Master file includes versioned changesets | Numbered migration files |
| Spring Boot dep | `org.liquibase:liquibase-core` | `org.flywaydb:flyway-core` |
| Quarkus dep | `io.quarkus:quarkus-liquibase` | `io.quarkus:quarkus-flyway` |

## Liquibase

### Configuration

```yaml
# Spring Boot
spring:
  liquibase:
    change-log: classpath:db/changeLog.yaml
    default-schema: my_schema  # optional

# Quarkus
quarkus:
  liquibase:
    migrate-at-start: true
    change-log: db/changeLog.yaml
    default-schema: my_schema  # optional
```

### Directory structure

```
src/main/resources/db/
├── changeLog.yaml
├── v1/
│   ├── 01-04-2026--initial-schema.yaml
│   └── 01-04-2026--add-indexes.yaml
└── v2/
    └── 10-04-2026--add-comments-table.yaml
```

### Master changelog

```yaml
databaseChangeLog:
  - include:
      file: db/v1/01-04-2026--initial-schema.yaml
  - include:
      file: db/v1/01-04-2026--add-indexes.yaml
```

### Changeset example

```yaml
databaseChangeLog:
  - changeSet:
      id: create-article
      author: developer
      changes:
        - createTable:
            tableName: article
            columns:
              - column:
                  name: id
                  type: uuid
                  defaultValueComputed: gen_random_uuid()
                  constraints:
                    primaryKey: true
                    nullable: false
              - column:
                  name: title
                  type: varchar(255)
                  constraints:
                    nullable: false
              - column:
                  name: status
                  type: varchar(50)
                  constraints:
                    nullable: false
              - column:
                  name: category_id
                  type: uuid
                  constraints:
                    nullable: false
              - column:
                  name: created_at
                  type: timestamptz
                  constraints:
                    nullable: false
              - column:
                  name: updated_at
                  type: timestamptz
                  constraints:
                    nullable: false
              - column:
                  name: version
                  type: integer
                  defaultValueNumeric: 0
                  constraints:
                    nullable: false
        - addForeignKeyConstraint:
            constraintName: fk_article_category
            baseTableName: article
            baseColumnNames: category_id
            referencedTableName: category
            referencedColumnNames: id
        # ALWAYS create indexes on FK columns — databases do NOT auto-index them
        - createIndex:
            indexName: idx_article_category_id
            tableName: article
            columns:
              - column:
                  name: category_id
```

## Flyway

### Configuration

```yaml
# Spring Boot
spring:
  flyway:
    locations: classpath:db/migration
    schemas: my_schema  # optional

# Quarkus
quarkus:
  flyway:
    migrate-at-start: true
    locations: db/migration
    schemas: my_schema  # optional
```

### Directory structure

```
src/main/resources/db/migration/
├── V1__initial_schema.sql
├── V2__add_comments_table.sql
└── V3__add_indexes.sql
```

### Migration example

```sql
CREATE TABLE article (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    category_id UUID NOT NULL REFERENCES category(id),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    version INTEGER NOT NULL DEFAULT 0
);

-- FK indexes are MANDATORY — databases do NOT auto-index foreign keys
CREATE INDEX idx_article_category_id ON article(category_id);

-- Join table example: BOTH FK columns need indexes
CREATE TABLE article_tag (
    article_id UUID NOT NULL REFERENCES article(id),
    tag_id UUID NOT NULL REFERENCES tag(id),
    PRIMARY KEY (article_id, tag_id)
);
CREATE INDEX idx_article_tag_tag_id ON article_tag(tag_id);
-- article_id is covered by PK, but tag_id needs a separate index for reverse lookups
```

## Type Mapping

| Kotlin/Java Type | PostgreSQL | MySQL |
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

## Annotation → Constraint Alignment

| Jimmer Annotation | DB Constraint |
|---|---|
| `@OnDissociate(DELETE)` | FK with `ON DELETE CASCADE` |
| `@OnDissociate(SET_NULL)` | FK with `ON DELETE SET NULL` |
| `@Key` fields | UNIQUE constraint |
| `@Version` | INTEGER column, default 0 |
| `@OneToOne @JoinColumn` | FK (consider UNIQUE on FK column) |

## Index Rules

**CRITICAL: Always create indexes on ALL FK columns.** PostgreSQL and most databases do NOT auto-index foreign keys. Without indexes, JOINs and filtered queries on FK columns become full table scans.

```sql
-- Every FK column MUST have an index
CREATE INDEX idx_article_category_id ON article(category_id);
CREATE INDEX idx_comment_article_id ON comment(article_id);

-- Join table: both FK columns need indexes (PK covers one, add index for the other)
-- If PK is (recipe_id, tag_id), add index on tag_id for reverse lookups
CREATE INDEX idx_recipe_tag_tag_id ON recipe_tag(tag_id);
```

**Checklist:**
- Every `@ManyToOne` FK column → index
- Every `@OneToMany` inverse FK column → index
- Every `@ManyToMany` join table → indexes on both FK columns (PK covers one direction, index needed for reverse)
- `@Key` columns → covered by UNIQUE constraint (no separate index needed)
- Columns frequently used in WHERE clauses → index
