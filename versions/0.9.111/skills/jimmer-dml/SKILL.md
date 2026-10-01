---
name: jimmer-dml
description: Implement Jimmer Java/Kotlin bulk updates, deletes and batched graph writes; handle conditional row counts without unavailable insert-select/upsert-returning APIs.
metadata:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Bulk mutations

The official release supports typed `createUpdate` / `createDelete` and graph save batches. It does **not** expose query-derived `createInsert`, `createUpsert`, `createUpdateReturning` or mutation `.returning(...)`. Do not confuse its supported base queries with a query-to-table insert API.

## Conditional atomic update

Assume `Book` has ID, a price and an optimistic `version`. Java:

```java
var b = Tables.BOOK_TABLE;
int changed = sqlClient.createUpdate(b)
    .set(b.price(), b.price().plus(delta))
    .set(b.version(), b.version().plus(1))
    .where(b.id().eq(id), b.version().eq(expectedVersion))
    .execute();
```

Kotlin:

```kotlin
val changed = sqlClient.createUpdate(Book::class) {
    set(table.price, table.price + delta)
    set(table.version, table.version + 1)
    where(table.id eq id, table.version eq expectedVersion)
}.execute()
```

Here zero rows means no matching ID/version, and one means this conditional update succeeded. Handle zero deliberately. Add the caller's required authorization predicate; a query filter is not proof of mutation authorization. Unlike a graph save, bulk update requires you to write version comparison/increment explicitly. It does not invoke graph-save preprocessors/interceptors as if each row were saved separately.

## Bulk delete / insert

Java `sqlClient.createDelete(Tables.BOOK_TABLE).where(...).execute()` and Kotlin `sqlClient.createDelete(Book::class) { where(...) }.execute()` return counts. Verify logical deletion, association dissociation and trigger behavior; do not bypass them casually with raw SQL.

For existing objects use `saveEntitiesCommand(rows).setMode(SaveMode.INSERT_ONLY).execute()` in Java or `saveEntities(rows) { setMode(SaveMode.INSERT_ONLY) }` in Kotlin. Choose `UPSERT`/`INSERT_IF_ABSENT` only if that conflict policy is required. These are graph mutations, not guaranteed one-statement insert-select operations.

For large copy/import work use bounded read batches plus batch saves if materializing rows is acceptable. A requirement for database-native `INSERT ... SELECT`, constant application memory or returning changed rows may require reviewed parameterized SQL via the project's existing JDBC access. Preserve transaction ownership and cache invalidation; transaction triggers only observe Jimmer-managed mutations, while external/native writes need delivered CDC or another explicit invalidation path. Do not invent a later Jimmer API or silently relax the memory/atomicity contract.

Verify stored values, zero-row branch, rollback and affected counts on the actual dialect. For returned full rows, an explicit read in the appropriate transaction/isolation scope may be necessary; counts are not result objects.

Sources: [JSqlClient](https://github.com/babyfish-ct/jimmer/blob/v0.9.111/project/jimmer-sql/src/main/java/org/babyfish/jimmer/sql/JSqlClient.java), [KSqlClient](https://github.com/babyfish-ct/jimmer/blob/v0.9.111/project/jimmer-sql-kotlin/src/main/kotlin/org/babyfish/jimmer/sql/kt/KSqlClient.kt).
