---
description: "Generate a database migration (Liquibase YAML or Flyway SQL) for Jimmer entity changes"
---

# Migration Generator — STRICT WORKFLOW

## Step 1: Scan the project

- Read `application.yml` to determine the migration tool (Liquibase or Flyway)
- Find existing migration files — note the naming convention and directory
- Determine the next version/filename from existing files

## Step 2: Identify the change

Ask the user if unclear:
- New table, new column, new FK, new index, drop, or rename?
- Which entity / table is affected?

## Step 3: Write the migration

Follow the project's existing format exactly. Use the reference below.

## Step 4: Update master changelog (Liquibase only)

Add the new file entry to `changeLog.yaml`.

## Step 5: Compile

Execute `ls gradlew mvnw 2>/dev/null` as a tool call and wait for the output. The build command is chosen strictly from that output — do not assume a wrapper exists before seeing the result:
- output contains `gradlew` → `./gradlew compileJava` / `./gradlew compileKotlin`
- output contains `mvnw` → `./mvnw compile`
- output is empty → check for `pom.xml` → `mvn compile`, or `build.gradle` → `gradle compileJava` / `gradle compileKotlin`

Fix errors. Done.

---

# Reference

## Type mapping

| Kotlin/Java | PostgreSQL | MySQL |
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

## Annotation → constraint alignment

| Jimmer annotation | DB constraint |
|---|---|
| `@OnDissociate(DELETE)` | `ON DELETE CASCADE` |
| `@OnDissociate(SET_NULL)` | `ON DELETE SET NULL` |
| `@Key` | UNIQUE constraint on @Key columns |
| `@Version` | `integer NOT NULL DEFAULT 0` |
| `@OneToOne @JoinColumn` | FK + consider UNIQUE on FK column |

## Index rules

Create an index on every FK column — databases do not auto-index foreign keys.

- `@ManyToOne` FK column → index
- `@OneToMany` inverse FK column → index
- `@ManyToMany` join table → index on both FK columns (PK covers one direction, add index for the other)
- `@Key` columns → covered by the UNIQUE constraint, no extra index needed

## Liquibase example

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
        - createIndex:
            indexName: idx_article_category_id
            tableName: article
            columns:
              - column:
                  name: category_id
```

## Flyway example

```sql
CREATE TABLE article (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       VARCHAR(255) NOT NULL,
    status      VARCHAR(50)  NOT NULL,
    category_id UUID         NOT NULL REFERENCES category(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ  NOT NULL,
    version     INTEGER      NOT NULL DEFAULT 0
);

CREATE INDEX idx_article_category_id ON article(category_id);

-- Join table: PK covers one FK, add index for the reverse direction
CREATE TABLE article_tag (
    article_id UUID NOT NULL REFERENCES article(id),
    tag_id     UUID NOT NULL REFERENCES tag(id),
    PRIMARY KEY (article_id, tag_id)
);
CREATE INDEX idx_article_tag_tag_id ON article_tag(tag_id);
```
