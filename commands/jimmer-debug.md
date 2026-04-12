---
description: "Diagnose Jimmer ORM errors — NeitherIdNorKey, CannotDissociateTarget, save failures, query issues"
---

# Jimmer Debugger

Diagnose Jimmer errors using the error catalog below.

## Process

1. **Collect information** — ask the user:
   - Error message or exception class name
   - The entity being saved or queried
   - The save/query code that triggered the error
   - Jimmer SQL logs if available (look for QueryReason)

2. **Identify the error type:**
   - SaveException subtypes (NeitherIdNorKey, CannotDissociateTarget, NotUnique, etc.)
   - UnloadedPropertyException
   - OptimisticLockError (missing @Version in partial update?)
   - Database constraint violations
   - QueryReason warnings in logs

3. **Match to error catalog** (see below)

4. **Trace the entity tree:**
   - Which entity in the save tree caused the error?
   - Check the `exportedPath` from SaveException
   - Inspect @Key, @OnDissociate, @KeyUniqueConstraint annotations
   - Check DB constraints alignment

5. **Provide diagnosis:**
   - Root cause (why this error happened)
   - Specific fix (what annotation/code/constraint to change)
   - Code example showing the fix (using correct DSL: Kotlin `Entity { ... }`, Java `Immutables.createEntity()`)
   - How to verify the fix worked

## Common Quick Fixes

- **NeitherIdNorKey** → add `@Key` or use `VIOLENTLY_REPLACE`
- **CannotDissociateTarget** → add `@OnDissociate(DissociateAction.DELETE)`
- **NotUnique on @OneToOne** → remove `@Key` from child, use `VIOLENTLY_REPLACE`
- **QueryReason.KEY_UNIQUE_CONSTRAINT_REQUIRED** → add `@KeyUniqueConstraint` + DB unique constraint
- **UnloadedPropertyException** → add property to Fetcher/View or check with `ImmutableObjects.isLoaded()`
- **OptimisticLockError** → include `@Version` field in partial update, or re-read and retry

---

# Error Catalog

## Save Errors (SaveException subtypes)

### NeitherIdNorKey

**Message:** `Cannot save entity without id or key properties`

**Cause:** Jimmer needs to identify a child entity (for UPSERT, REPLACE, MERGE) but found neither a known `@Id` value nor `@Key` properties.

**When it happens:**
- Saving a child entity via `REPLACE` or `MERGE` mode
- The child entity has no `@Key` annotation and the `@Id` was not provided

**Fix options:**
1. Add `@Key` to the child entity on a natural business field
2. Use `AssociatedSaveMode.VIOLENTLY_REPLACE` (doesn't need identity — deletes all + re-inserts)
3. Provide the `@Id` value explicitly

---

### CannotDissociateTarget

**Message:** `Cannot dissociate child objects because the dissociate action is not configured`

**Cause:** `AssociatedSaveMode.REPLACE` found children in DB that are not in the new collection, but doesn't know how to handle them.

**When it happens:**
- Using `REPLACE` mode on a `@OneToMany` or `@OneToOne` association
- The association has no `@OnDissociate` annotation

**Fix:** Add `@OnDissociate(DissociateAction.DELETE)` on the association:

```kotlin
@OneToMany(mappedBy = "parent")
@OnDissociate(DissociateAction.DELETE)
val children: List<Child>
```

Also ensure the corresponding FK constraint in the database has `ON DELETE CASCADE` for consistency.

---

### NotUnique (duplicate key violation)

**Message:** `Save error caused by constraint violation`

**Cause:** An INSERT or UPDATE would violate a UNIQUE constraint in the database.

**Common scenarios:**
1. Two entities with the same `@Key` values being inserted simultaneously
2. `@Key` on a `@OneToOne` child entity shared by multiple parents → Jimmer reuses the same row
3. Conflicting data in batch saves

**Fix for @OneToOne case:** Remove `@Key` from the child entity, use `VIOLENTLY_REPLACE`.

---

### NoKeyProp

**Message:** `Entity type has no key properties`

**Cause:** Save operation requires `@Key` (e.g., UPSERT without known @Id, REPLACE for children) but the entity has no `@Key`-annotated properties.

**Fix:** Add `@Key` to appropriate properties, or use a save mode that doesn't require identity (`VIOLENTLY_REPLACE`, `INSERT_ONLY`).

---

### OptimisticLockError

**Message:** `Save error caused by optimistic lock`

**Cause:** Entity has `@Version` field, and the version in DB doesn't match the version being saved. Another transaction modified the entity between read and write.

**Fix:** Retry the operation (re-read, re-modify, re-save). This is expected behavior for optimistic locking.

---

### NullTarget

**Message:** `The target of association cannot be null`

**Cause:** A non-nullable FK association is being set to null during save.

**Fix:** Either make the association nullable (`val parent: Parent?`) or ensure the FK value is always provided.

---

### NoIdGenerator

**Message:** `No id generator configured for entity`

**Cause:** Entity has `@GeneratedValue` but no matching ID generator is configured.

**Fix:** Ensure `@GeneratedValue(generatorType = UUIDIdGenerator::class)` or `@GeneratedValue(strategy = GenerationType.IDENTITY)` is properly configured.

---

### ReversedRemoteAssociation

**Message:** `Remote associations cannot be reversed`

**Cause:** Trying to use a remote (cross-microservice) association in the inverse direction.

**Fix:** Only use remote associations from the owning side.

---

### TargetIsNotTransferable

**Message:** `Target entity cannot be transferred to another parent`

**Cause:** A child entity (identified by @Id or @Key) already belongs to a different parent, and REPLACE mode is trying to move it.

**Fix:** Delete the child from the old parent first, or use `VIOLENTLY_REPLACE`.

---

### IncompleteProperty

**Message:** `Not all key properties are specified`

**Cause:** Entity has composite `@Key` but not all key properties were set in the save input.

**Fix:** Ensure all `@Key`-annotated properties have values in the entity being saved.

---

## Query Reasons (extra SELECTs in logs)

These appear in Jimmer's SQL logs explaining why an additional SELECT was executed during save operations.

### QueryReason.TRIGGER

Extra SELECT to capture old state before mutation — required by `TRANSACTION_ONLY` trigger mode.

**Expected behavior.** N entities = N extra SELECTs. If this is too expensive, consider:
- Using `BINLOG_ONLY` triggers (async, no extra SELECT)
- Disabling triggers for batch operations

### QueryReason.KEY_UNIQUE_CONSTRAINT_REQUIRED

Entity has `@Key` but no `@KeyUniqueConstraint`. Jimmer cannot use `INSERT ON CONFLICT` and falls back to SELECT → INSERT/UPDATE.

**Fix:** Add `@KeyUniqueConstraint` on the entity AND create the corresponding unique constraint in the database.

### QueryReason.INTERCEPTOR

Extra SELECT to provide `original` parameter to `DraftInterceptor.beforeSave()`.

**Expected behavior.** The interceptor needs the old entity state. If not needed, remove the interceptor for pure INSERT operations.

### QueryReason.CHECKING

Jimmer is checking parent/child existence for FK validation.

### QueryReason.IDENTITY_GENERATOR_REQUIRED

Extra SELECT to retrieve database-generated ID after INSERT.

### QueryReason.INVESTIGATE_CONSTRAINT_VIOLATION_ERROR

After a constraint violation, Jimmer queries to determine which specific constraint was violated and provide a meaningful error.

---

## Runtime Errors

### UnloadedPropertyException

**Message:** `Property "Entity.property" is not loaded`

**Cause:** Accessing a property on an entity that was loaded with a partial projection (Fetcher or View that didn't include this property).

**When it happens:**
- Entity loaded via `table.fetch(SomeView::class)` that doesn't include the accessed property
- Entity from an event (`EntityEvent.oldEntity`/`newEntity`) that only has partial data

**Fix:**
1. Add the property to the Fetcher/View
2. Re-load the entity with a complete Fetcher before accessing the property
3. Use `ImmutableObjects.isLoaded(entity, prop)` to check before accessing

```kotlin
if (ImmutableObjects.isLoaded(article, ArticleProps.CONTENT)) {
    val content = article.content
}
```

---

### CircularReferenceException

**Cause:** Entity graph has circular references that Jimmer cannot serialize.

**Fix:** Use `@JsonIgnore` on one side of the circular reference, or use View/Fetcher to control which associations are loaded.

---

## Database-Level Errors

### FK constraint violation

**Jimmer context:** Usually happens when:
- `@OnDissociate(DissociateAction.DELETE)` is set but DB doesn't have `ON DELETE CASCADE` → Jimmer deletes child, but grandchild FK blocks it
- Saving an entity with a FK to a non-existent parent

**Fix:** Align DB constraints with Jimmer annotations. If `@OnDissociate(DELETE)`, add `ON DELETE CASCADE` to the FK.

### Unique constraint violation (not SaveException)

**Jimmer context:** Raw database error, not wrapped by Jimmer. Usually from:
- Concurrent inserts with same natural key (no `@KeyUniqueConstraint`)
- Application logic error (duplicate data)

**Fix:** Add `@KeyUniqueConstraint` for atomic upsert, or handle at application level.

---

## Diagnostic Checklist

When a save fails:

1. **Read the exception type** — SaveException subtypes tell you exactly what's wrong
2. **Check the `exportedPath`** — shows which entity in the save tree caused the error
3. **Check the `saveErrorCode`** — machine-readable error code
4. **Verify @Key** — does the child entity need identity? Does it have @Key?
5. **Verify @OnDissociate** — are you using REPLACE mode? Is dissociation configured?
6. **Verify DB constraints** — do unique/FK constraints match Jimmer annotations?
7. **Check QueryReason in logs** — extra SELECTs may hint at missing annotations
