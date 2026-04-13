# Jimmer Save Modes

## @Key

Defines natural/business identity. Used to find existing records during save.

- **Without `@KeyUniqueConstraint`:** SELECT → INSERT/UPDATE (race condition)
- **With `@KeyUniqueConstraint` + DB constraint:** atomic `INSERT ON CONFLICT DO UPDATE`

```java
@Key
@ManyToOne
@JoinColumn(name = "category_id")
Category category();  // @Key on FK — identity by FK value
```

Composite keys can mix scalar + FK fields. **Don't add @Key on @OneToOne children** shared by multiple parents.

---

## SaveMode (Root Entity)

| Mode | Behavior |
|---|---|
| `INSERT_ONLY` | INSERT; error if exists |
| `INSERT_IF_ABSENT` | INSERT if absent; no error if exists |
| `UPDATE_ONLY` | UPDATE; error if not exists |
| `UPSERT` | SELECT → INSERT or UPDATE by @Id/@Key |
| `NON_IDEMPOTENT_UPSERT` | `INSERT ON CONFLICT DO UPDATE` (single query, best for bulk) |

---

## AssociatedSaveMode (Child Entities)

| Mode | Insert | Update | Delete missing |
|---|---|---|---|
| `REPLACE` | ✓ | ✓ | ✓ (diff by @Id/@Key, needs `@OnDissociate`) |
| `MERGE` | ✓ | ✓ | ✗ |
| `APPEND` | ✓ | ✗ (error) | ✗ |
| `APPEND_IF_ABSENT` | ✓ (skip existing) | ✗ | ✗ |
| `UPDATE` | ✗ (error) | ✓ | ✗ |
| `VIOLENTLY_REPLACE` | ✓ | ✓ | ✓ (DELETE ALL + re-INSERT, no @Key needed) |

**FK-based associations** (`@OneToOne @JoinColumn`, `@ManyToOne`) follow root SaveMode by default. Override with `setAssociatedMode()`.

---

## Save API

```java
// Single entity — saveCommand
sql.saveCommand(article)
    .setMode(SaveMode.UPSERT)
    .setAssociatedModeAll(AssociatedSaveMode.REPLACE)  // same mode for all associations
    .execute();

// Per-property override
sql.saveCommand(article)
    .setMode(SaveMode.UPDATE_ONLY)
    .setAssociatedMode(ArticleProps.COMMENTS, AssociatedSaveMode.REPLACE)
    .setAssociatedMode(ArticleProps.METADATA, AssociatedSaveMode.VIOLENTLY_REPLACE)
    .setAssociatedMode(ArticleProps.TAGS, AssociatedSaveMode.APPEND_IF_ABSENT)
    .execute();

// Batch — saveEntitiesCommand
sql.saveEntitiesCommand(articles)
    .setMode(SaveMode.NON_IDEMPOTENT_UPSERT)
    .setAssociatedModeAll(AssociatedSaveMode.REPLACE)
    .execute();

// Return View from save (no extra query)
RecipeDetailView view = repository.saveCommand(input)
    .setMode(SaveMode.INSERT_ONLY)
    .execute(RecipeDetailView.class)
    .getModifiedView();
```

---

## Save Result

**Never re-query after save.** Use the result directly.

```java
// Via JRepository — save() returns entity
Article saved = repository.save(article, SaveMode.INSERT_ONLY);
// saved has generated ID, timestamps, version

// Via saveCommand — execute() returns SimpleSaveResult
Article saved = sql.saveCommand(article)
    .setMode(SaveMode.INSERT_ONLY)
    .execute()
    .getModifiedEntity();

// Via saveCommand with View — execute(ViewClass) returns View
RecipeDetailView view = sql.saveCommand(input)
    .setMode(SaveMode.INSERT_ONLY)
    .execute(RecipeDetailView.class)
    .getModifiedView();
```

`SimpleSaveResult`: `getModifiedEntity()`, `getOriginalEntity()`.
`BatchSaveResult` (for `saveEntitiesCommand`): `getItems()` — list of `SimpleSaveResult`.

---

## Deprecated Methods

`insert()`, `update()` are deprecated. Use `save()` with explicit SaveMode:

```java
// WRONG
repository.insert(entity);
// CORRECT
repository.save(entity, SaveMode.INSERT_ONLY);
```

---

## Common Errors

- **NeitherIdNorKey** → use `VIOLENTLY_REPLACE` or add `@Key` to child
- **CannotDissociateTarget** → add `@OnDissociate(DissociateAction.DELETE)` on FK side
- **Duplicate key on @OneToOne** → remove `@Key` from child, use `VIOLENTLY_REPLACE`

---

## Decision Tree

1. Root **known to exist**? → `UPDATE_ONLY`
2. Root **known to be new**? → `INSERT_ONLY`
3. Root **may or may not exist**? → `UPSERT` (with @Key) or provide @Id
4. **Bulk upsert**? → `NON_IDEMPOTENT_UPSERT`
5. Children **full sync**? → `REPLACE` (needs @Key + @OnDissociate)
6. Children **full sync, no @Key**? → `VIOLENTLY_REPLACE`
7. Children **only add**? → `APPEND` / `APPEND_IF_ABSENT`
8. Children **add + update, no delete**? → `MERGE`
9. **@OneToOne FK-based**? → explicit `setAssociatedMode()` with `VIOLENTLY_REPLACE`
