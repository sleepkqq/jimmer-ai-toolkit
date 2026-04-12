# Jimmer Save Modes

## @Key

Defines the natural/business identity of an entity. Jimmer uses `@Key` fields to find existing records during save operations.

**Without DB unique constraint:** SELECT → INSERT/UPDATE (race condition possible). Jimmer logs `QueryReason.KEY_UNIQUE_CONSTRAINT_REQUIRED`.

**With `@KeyUniqueConstraint` + DB constraint:** `INSERT ON CONFLICT DO UPDATE` (atomic, no race condition).

### @Key on FK fields

```kotlin
@Key
@ManyToOne
@JoinColumn(name = "category_id")
val category: Category
```

Identity is determined by the FK value. Composite keys can mix scalar and FK fields.

### Danger: @Key on @OneToOne child

If a child entity has `@Key` and is used in `@OneToOne` by multiple parents, Jimmer will reuse the same child row for parents with matching key values → FK/PK violation.

**Rule:** do NOT put `@Key` on entities used as `@OneToOne` children by multiple parents.

---

## SaveMode (Root Entity)

| Mode | Behavior |
|---|---|
| `INSERT_ONLY` | INSERT only; error if already exists |
| `INSERT_IF_ABSENT` | INSERT if absent; ignore (no error) if exists |
| `UPDATE_ONLY` | UPDATE only; error if not exists |
| `UPSERT` | SELECT → INSERT or UPDATE based on @Id / @Key |
| `NON_IDEMPOTENT_UPSERT` | `INSERT ON CONFLICT DO UPDATE` without prior SELECT |

### UPSERT vs NON_IDEMPOTENT_UPSERT

- `UPSERT`: does SELECT first → two queries, but works with DraftInterceptor and triggers
- `NON_IDEMPOTENT_UPSERT`: single query, more efficient for bulk, but may cause extra trigger firings if Jimmer cannot determine if it was INSERT or UPDATE

---

## AssociatedSaveMode (Child Entities)

| Mode | Insert new | Update existing | Delete missing |
|---|---|---|---|
| `REPLACE` | Yes | Yes | Yes (diff by @Id/@Key) |
| `MERGE` | Yes | Yes | No |
| `APPEND` | Yes | No (error if exists) | No |
| `APPEND_IF_ABSENT` | Yes (skip if exists) | No | No |
| `UPDATE` | No (error if absent) | Yes | No |
| `VIOLENTLY_REPLACE` | Yes | Yes | Yes (DELETE ALL + re-INSERT) |

### REPLACE

Full collection sync: compares old vs new by `@Id`/`@Key`, inserts new, updates changed, deletes removed.

**Requires:** `@OnDissociate(DissociateAction.DELETE)` on the association. Without it → `CannotDissociateTarget` exception.

### VIOLENTLY_REPLACE

`DELETE WHERE parent_id = ?` + INSERT all. Does NOT require `@Key` on child — no identity matching needed.

**Use when:** child entity has no meaningful `@Key`, or for `@OneToOne` FK-based associations.

### FK-based associations

`@OneToOne @JoinColumn` and `@ManyToOne` associations ignore the default `AssociatedSaveMode`. They follow the root `SaveMode` instead. To control them explicitly, use `setAssociatedMode()`.

---

## Save API

### Kotlin

```kotlin
// Single entity
sql.save(article, SaveMode.UPSERT, AssociatedSaveMode.REPLACE)

// Batch
sql.saveEntities(articles, SaveMode.NON_IDEMPOTENT_UPSERT, AssociatedSaveMode.REPLACE)

// With per-property overrides
sql.saveEntities(articles, SaveMode.NON_IDEMPOTENT_UPSERT, AssociatedSaveMode.REPLACE) {
    setAssociatedMode(Article::comments, AssociatedSaveMode.REPLACE)
    setAssociatedMode(Article::metadata, AssociatedSaveMode.VIOLENTLY_REPLACE)
}
```

### Java

```java
// Single entity
sql.saveCommand(article)
    .setMode(SaveMode.UPSERT)
    .setAssociatedModeAll(AssociatedSaveMode.REPLACE)
    .execute();

// Batch
sql.saveEntitiesCommand(articles)
    .setMode(SaveMode.NON_IDEMPOTENT_UPSERT)
    .setAssociatedModeAll(AssociatedSaveMode.REPLACE)
    .setAssociatedMode(ArticleProps.METADATA, AssociatedSaveMode.VIOLENTLY_REPLACE)
    .execute();
```

### Save result — always use it directly

**Never do a separate query after save.** The save result already contains the full entity.

**Via KRepository/JRepository** — `save()` returns entity directly:

```kotlin
// KRepository.save() already extracts modifiedEntity internally
val saved: Article = repository.save(article, SaveMode.INSERT_ONLY)
// saved contains generated ID, timestamps, version — ready to use
```

**Via raw KSqlClient/JSqlClient** — `save()` returns `SimpleSaveResult`, use `.modifiedEntity`:

```kotlin
val saved = sql.save(article, SaveMode.INSERT_ONLY).modifiedEntity
```

```java
Article saved = sql.saveCommand(article)
    .setMode(SaveMode.INSERT_ONLY)
    .execute()
    .getModifiedEntity();
```

**NEVER re-query after save:**
```kotlin
// WRONG — repository.save() already returned the entity
val saved = repository.save(article, SaveMode.INSERT_ONLY)
val full = repository.findNullable(saved.id)  // WASTEFUL
```

`SimpleSaveResult` fields:
- `modifiedEntity` — entity after save (with generated ID, timestamps, etc.)
- `originalEntity` — entity before save (for update: previous state; for insert: empty)

`BatchSaveResult` for `saveEntities()`:
- `items` — list of `SimpleSaveResult` per entity

### Deprecated methods (Jimmer 0.10.x)

`JRepository.insert()`, `JRepository.update()`, `KRepository.insert()`, `KRepository.update()` are **deprecated**. Always use `save()` with explicit `SaveMode`:

```kotlin
// WRONG — deprecated
repository.insert(entity)
repository.update(entity)

// CORRECT
sql.save(entity, SaveMode.INSERT_ONLY)
sql.save(entity, SaveMode.UPDATE_ONLY)
```

---

## setAssociatedMode() — Per-Property Override

Different associations in the same entity tree can have different save modes:

```kotlin
sql.saveEntities(orders, SaveMode.NON_IDEMPOTENT_UPSERT, AssociatedSaveMode.MERGE) {
    // Line items: full sync — add new, update changed, delete removed
    setAssociatedMode(Order::lineItems, AssociatedSaveMode.REPLACE)

    // Shipping address: @OneToOne FK-based — delete old, insert new
    setAssociatedMode(Order::shippingAddress, AssociatedSaveMode.VIOLENTLY_REPLACE)

    // Tags: just add new associations, never remove
    setAssociatedMode(Order::tags, AssociatedSaveMode.APPEND_IF_ABSENT)
}
```

---

## @OnDissociate

Required for `REPLACE` mode. See **jimmer-entity-design.md → @OnDissociate — Child Lifecycle** for full reference.

Without `@OnDissociate` + `REPLACE` → `CannotDissociateTarget` exception.

---

## Typical Scenarios

### Seed job: full sync from config

Need: insert new, update changed, delete removed.

```kotlin
sql.saveEntities(items, SaveMode.NON_IDEMPOTENT_UPSERT, AssociatedSaveMode.REPLACE) {
    // @OneToOne FK-based needs explicit override
    setAssociatedMode(Item::localization, AssociatedSaveMode.VIOLENTLY_REPLACE)
}
```

### Simple insert

```kotlin
sql.save(article, SaveMode.INSERT_ONLY)
```

### Update known entity

```kotlin
sql.save(article, SaveMode.UPDATE_ONLY)
```

### Add children without removing existing

```kotlin
sql.save(article, SaveMode.UPDATE_ONLY, AssociatedSaveMode.APPEND_IF_ABSENT)
```

---

## Common Errors

### NeitherIdNorKey

Jimmer cannot identify a child record — no `@Id` with known value and no `@Key`.

**Fix:** use `VIOLENTLY_REPLACE` (no identity needed) or add `@Key` to the child entity.

### CannotDissociateTarget

`REPLACE` mode wants to delete removed children but `@OnDissociate` is not set.

**Fix:** add `@OnDissociate(DissociateAction.DELETE)` on the association.

### Duplicate key on @OneToOne

`@Key` on child entity + `@OneToOne` from multiple parents → Jimmer reuses the same row.

**Fix:** remove `@Key` from child, use `VIOLENTLY_REPLACE`.

---

## Decision Tree

1. **Root entity known to exist?** → `UPDATE_ONLY`
2. **Root entity known to be new?** → `INSERT_ONLY`
3. **Root entity may or may not exist?** → `UPSERT` (has @Key) or provide @Id
4. **Bulk upsert with @Key?** → `NON_IDEMPOTENT_UPSERT` (most efficient)
5. **Children: full sync?** → `REPLACE` (needs @Key + @OnDissociate)
6. **Children: full sync, no @Key?** → `VIOLENTLY_REPLACE`
7. **Children: only add new?** → `APPEND` or `APPEND_IF_ABSENT`
8. **Children: add + update, no delete?** → `MERGE`
9. **@OneToOne FK-based child?** → explicit `setAssociatedMode()` with `VIOLENTLY_REPLACE`
