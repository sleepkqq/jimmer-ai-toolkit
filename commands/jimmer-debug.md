---
description: "Diagnose Jimmer ORM errors — NeitherIdNorKey, CannotDissociateTarget, save failures, query issues"
---

# Jimmer Debugger — STRICT WORKFLOW

## Step 1: Collect information

Ask the user for:
- Exception class name and message
- The entity being saved or queried
- The save/query code that triggered the error
- Jimmer SQL logs if available (look for `QueryReason`)

## Step 2: Match the error

Use the quick-fix table first. If not covered, consult the error catalog below.

## Step 3: Diagnose

- Identify which entity in the save tree caused the error (`exportedPath` in SaveException)
- Check `@Key`, `@OnDissociate`, `@KeyUniqueConstraint` annotations on the affected entity
- Verify DB constraints align with Jimmer annotations

## Step 4: Fix and compile

Apply the fix. Check the project root:
- `./gradlew` exists → `./gradlew compileJava` / `compileKotlin`
- `./mvnw` exists → `./mvnw compile`
- neither → `gradle` / `mvn`

---

## Quick-fix table

| Error | Fix |
|---|---|
| `NeitherIdNorKey` | Add `@Key` or use `VIOLENTLY_REPLACE` |
| `CannotDissociateTarget` | Add `@OnDissociate(DissociateAction.DELETE)` |
| `NotUnique` on @OneToOne | Remove `@Key` from child, use `VIOLENTLY_REPLACE` |
| `QueryReason.KEY_UNIQUE_CONSTRAINT_REQUIRED` | Add `@KeyUniqueConstraint` + DB unique constraint |
| `UnloadedPropertyException` | Add property to Fetcher/View or check with `ImmutableObjects.isLoaded()` |
| `OptimisticLockError` | Include `@Version` field in partial update, or re-read and retry |

---

# Error Catalog

## NeitherIdNorKey

**Cause:** Jimmer needs to identify a child entity for UPSERT/REPLACE/MERGE but found neither a known `@Id` value nor `@Key` properties.

**Fix options:**
1. Add `@Key` to the child entity on a natural business field
2. Use `AssociatedSaveMode.VIOLENTLY_REPLACE` (deletes all + re-inserts, no identity needed)
3. Provide the `@Id` value explicitly

---

## CannotDissociateTarget

**Cause:** `AssociatedSaveMode.REPLACE` found DB children not present in the new collection, but `@OnDissociate` is not configured.

**Fix:**

```java
@OneToMany(mappedBy = "parent")
@OnDissociate(DissociateAction.DELETE)
List<Child> children();
```

Align the DB FK constraint: add `ON DELETE CASCADE` if using `DELETE`.

---

## NotUnique

**Cause:** INSERT or UPDATE violates a UNIQUE constraint.

**Fix for @OneToOne case:** Remove `@Key` from the child entity and use `VIOLENTLY_REPLACE`. For general duplicate data — handle at application level or add `@KeyUniqueConstraint` for atomic upsert.

---

## NoKeyProp

**Cause:** Operation requires `@Key` (UPSERT without @Id, REPLACE for children) but entity has no `@Key`.

**Fix:** Add `@Key` to appropriate fields, or use `VIOLENTLY_REPLACE` / `INSERT_ONLY`.

---

## OptimisticLockError

**Cause:** Entity has `@Version` and DB version doesn't match the value being saved — another transaction modified the entity.

**Fix:** Re-read the entity, re-apply changes, re-save. Expected behavior for optimistic locking.

---

## NullTarget

**Cause:** Non-nullable FK association is being set to null during save.

**Fix:** Make the association nullable (`Parent?`) or always provide the FK value.

---

## NoIdGenerator

**Cause:** Entity has `@GeneratedValue` but no matching generator is configured.

**Fix:** Set `@GeneratedValue(generatorType = UUIDIdGenerator::class)` or `@GeneratedValue(strategy = GenerationType.IDENTITY)`.

---

## TargetIsNotTransferable

**Cause:** A child entity already belongs to a different parent, and REPLACE mode is trying to move it.

**Fix:** Delete the child from the old parent first, or use `VIOLENTLY_REPLACE`.

---

## IncompleteProperty

**Cause:** Entity has composite `@Key` but not all key properties were set in the save input.

**Fix:** Ensure every `@Key`-annotated property has a value in the entity being saved.

---

## UnloadedPropertyException

**Cause:** Accessing a property that was not included in the Fetcher/View used to load the entity.

**Fix:**

```java
if (ImmutableObjects.isLoaded(article, ArticleProps.CONTENT)) {
    String content = article.content();
}
```

Or add the property to the Fetcher/View.

---

## QueryReason in logs (extra SELECTs)

| QueryReason | Meaning | Action |
|---|---|---|
| `TRIGGER` | SELECT before mutation for `TRANSACTION_ONLY` trigger | Expected — consider `BINLOG_ONLY` if too expensive |
| `KEY_UNIQUE_CONSTRAINT_REQUIRED` | No `@KeyUniqueConstraint` → falls back to SELECT + INSERT/UPDATE | Add `@KeyUniqueConstraint` + DB unique constraint |
| `INTERCEPTOR` | SELECT to provide `original` to `DraftInterceptor.beforeSave()` | Expected — remove interceptor if old state isn't needed |
| `CHECKING` | FK parent/child existence validation | Expected |
| `IDENTITY_GENERATOR_REQUIRED` | SELECT to retrieve DB-generated ID after INSERT | Expected |
| `INVESTIGATE_CONSTRAINT_VIOLATION_ERROR` | Post-violation SELECT to identify which constraint failed | Expected |
