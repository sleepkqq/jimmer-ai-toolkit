---
name: jimmer-performance
description: |
  Jimmer performance guide: using save results instead of re-querying (fetcher/view save results, DML returning), assignment expressions for atomic column math, bulk update returning, N+1 batch loading, fetchPage vs fetchSlice, exists vs count, QueryReason auditing, associated-mode costs, trigger/cache impact on bulk operations.
triggers:
  - "Jimmer performance"
  - "save then find"
  - "N+1"
  - "fetchSlice"
  - "QueryReason"
  - "slow query"
  - "re-query after save"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: guide
---

# Jimmer Performance

Use when writing or reviewing any Jimmer data path where round-trips matter. Core rule: count the SQL statements Jimmer emits (enable SQL log) — every statement must be explainable.

## Save results — never re-query

`save`/`saveCommand` returns everything the database produced: generated ids, bumped versions, the merged entity.

```kotlin
val saved = sqlClient.save(entity) { setMode(SaveMode.UPSERT) }.modifiedEntity
val ids = sqlClient.saveEntities(entities).items.map { it.modifiedEntity.id }
```

```java
DomainObjectDetailView view = repository.saveCommand(input)
    .execute(DomainObjectDetailView.class)   // returns the saved shape directly
    .getModifiedView();
```

`save` followed by `findById`/`find*` of the same aggregate is a defect: one extra round-trip and a read-after-write race. If callers need a different shape than the input, pass a fetcher or the View class to `execute(...)`.

How the result is materialized (cheapest first): values already known from the saved object are copied; unresolved local columns are read straight from the DML statement via `RETURNING` where the dialect supports it (H2, PostgreSQL); only the residual part of the requested shape (associations, formulas, non-local data) runs as follow-up queries. When the database itself may rewrite values (triggers, generated columns, normalization), enable `saveResultReadsAllProperties` so requested properties are read back instead of copied.

## Upsert cost ladder (cheapest first)

1. `UPSERT` + `@KeyUniqueConstraint` + real DB unique constraint → single `INSERT ... ON CONFLICT`.
2. Any registered `DraftInterceptor` on the type → degrades to select-then-insert/update (`QueryReason: INTERCEPTOR`). Use `DraftPreProcessor` when no existence check is needed.
3. No `@KeyUniqueConstraint` → select-then-write always (`KEY_UNIQUE_CONSTRAINT_REQUIRED`) + race window.

Batch: `saveEntities`/`insertEntities` — one JDBC batch. A loop of single saves is N round-trips plus N interceptor queries.

## Atomic column math — assignment expressions

Counters and other read-modify-write patterns move into the database. `set(prop) { expression }` on a save command replaces the assignment for an already-loaded property:

```kotlin
sqlClient.save(Book { id = bookId; price = delta }) {
    setMode(SaveMode.UPDATE_ONLY)
    set(Book::price) { target.price + newNonNull(Book::price) }   // SET PRICE = PRICE + ?
}
```

Supported in `UPDATE_ONLY` and the update branch of `UPSERT`; the target must be a local scalar column already selected by the object shape (and allowed by the `UpsertMask` if present). When the post-update value is needed by the result or a trigger, Jimmer reads it via DML returning or a follow-up query — never assume it equals the input.

## Bulk update returning

When updated values are needed immediately, return them from the same statement instead of re-selecting:

```kotlin
val rows: List<Tuple2<Long, String>> =
    sqlClient.createUpdateReturning(Author::class) {
        set(table.firstName, concat(table.firstName, value("*")))
        where(table.firstName eq "Dan")
        returning(table.id, table.firstName)
    }.execute()          // or .stream() for large row sets
```

Java: `createUpdate(...).set(...).where(...).returning(...)`; Kotlin shortcut `executeUpdateReturning`. One selection → list of values, several → tuples.

## QueryReason audit

Every extra SELECT in the SQL log is tagged with a `QueryReason`. Treat unexpected reasons as findings: `INTERCEPTOR`, `TRIGGER` (transaction triggers need pre-images), `KEY_UNIQUE_CONSTRAINT_REQUIRED`, `OPTIMISTIC_LOCK`, `CANNOT_DELETE_DIRECTLY` (delete must select rows first — see below), `INVESTIGATE_CONSTRAINT_VIOLATION_ERROR` (only after an actual violation — fine).

## Deletes under triggers/cache

With `trigger-type: TRANSACTION_ONLY` (or cache invalidation), DSL/bulk deletes expand to select-rows-then-delete (`CANNOT_DELETE_DIRECTLY`) and `LIMIT` is unavailable in delete DSL. For hot-path pruning of tables that are NOT in the entity cache, a single native `DELETE WHERE id IN (SELECT ... LIMIT n)` statement is the correct tool; for cached entities never bypass the command API — you'd skip eviction.

## Pagination

| Need | API | Cost |
|---|---|---|
| Page with exact total | `fetchPage(page, size)` | data query + count query |
| Infinite scroll / typeahead ("has more?") | `fetchSlice(limit, offset)` → `slice.isTail` | one query with `limit+1`, no count |
| Existence only | `exists()` / `fetchExists()` | `select 1 ... limit 1`, no count scan |

Exact counts on search-as-you-type paths are wasted work — reach for `fetchSlice`.

Deep pages (large offset): set `offset-optimizing-threshold` (config or `setOffsetOptimizingThreshold`) — past the threshold Jimmer rewrites the page query to an id-first plan instead of a raw offset scan. Pair with a product-level page-depth cap.

## N+1 and fetch strategy

- Fetcher associations batch-load by default (batch 128 / list batch 16, configurable). N+1 appears when association access happens OUTSIDE a fetcher/view — always declare the shape.
- `ReferenceFetchType.JOIN_ALWAYS` (or `!fetchType(JOIN_ALWAYS)` in `.dto`) folds a reference into the main query — right for mandatory to-one refs without cache; `SELECT` keeps batching — right when the target is cached.
- Collection field config `batch(n)` / `limit(limit, offset)` bounds fan-out per parent.

## Selections with subqueries

A scalar subquery in a selection runs per result row. Before shipping one, check: can it be an uncorrelated `IN`/hash-friendly form, a join, or a windowed base query? Referencing the same subquery expression twice (e.g. in select and orderBy) may evaluate it twice — compute once into one expression. Verify with `EXPLAIN (ANALYZE, BUFFERS)`; green tests say nothing about per-row cost.

## Checklist before "done"

- [ ] SQL log reviewed: statement count matches expectations, no surprise QueryReason
- [ ] No save-then-find; results taken from the save command (`execute(fetcher)`/`modifiedView` for shapes)
- [ ] Counters/aggregates updated with assignment expressions, not read-modify-write
- [ ] Bulk updates that feed later logic use `returning(...)`, not a follow-up select
- [ ] Loops contain no queries; batch APIs used
- [ ] Pagination API matches product need (page vs slice vs exists)
- [ ] Selections free of unbounded per-row subqueries
