---
name: jimmer-save-modes
description: |
  Jimmer SaveMode and AssociatedSaveMode guide for inserts, updates, upserts, key matching, upsert masks, child replacement, save command options, and QueryReason.
triggers:
  - "SaveMode"
  - "AssociatedSaveMode"
  - "saveCommand"
  - "UpsertMask"
  - "QueryReason"
  - "VIOLENTLY_REPLACE"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Save Modes

Use for root save modes, child associated modes, key matching, save command options, and save results.

## Identity Rules

`@Key` defines natural/business identity for save matching.

- Key groups: `@Key(group = "a")` defines multiple independent keys; pick at save time with `setKeyProps("a", ...)`.
- Without `@KeyUniqueConstraint`: select then insert/update; race possible.
- With `@KeyUniqueConstraint` + real DB unique constraint (key columns + logical-delete flag column): SQL-level atomic upsert (`insert ... on conflict`).
- `@KeyUniqueConstraint(isNullNotDistinct = true)` (Postgres `NULLS NOT DISTINCT`) keeps SQL upsert when key props may be null; `noMoreUniqueConstraints = true` helps MySQL id-less upserts.
- Composite keys can mix scalar and FK fields.

## SaveMode (root objects only)

| Mode | Behavior |
|---|---|
| `INSERT_ONLY` | insert; error if exists |
| `INSERT_IF_ABSENT` | insert if absent, otherwise ignore |
| `UPDATE_ONLY` | update; nothing happens if missing |
| `UPSERT` | SQL upsert when possible, else select + insert/update; wild object (no id, no key) → `NeitherIdNorKey` error |
| `NON_IDEMPOTENT_UPSERT` | like UPSERT but unconditionally inserts wild objects (`saveOrUpdate` style; discouraged) |

## AssociatedSaveMode (associated objects)

| Mode | Insert | Update | Delete missing |
|---|---|---|---|
| `REPLACE` | yes | yes | yes — dissociation applies, targets need id or key |
| `MERGE` | yes | yes | no |
| `APPEND` | yes | no | no |
| `APPEND_IF_ABSENT` | skip existing | no | no |
| `UPDATE` | no | yes | no |
| `VIOLENTLY_REPLACE` | delete all + reinsert; accepts targets without id/key; slow, avoid |

## Save Command Options

```java
sql.saveCommand(domainObject)
    .setMode(SaveMode.UPSERT)
    .setAssociatedModeAll(AssociatedSaveMode.REPLACE)
    .setAssociatedMode(DomainObjectProps.CHILDREN, AssociatedSaveMode.MERGE)
    .execute();
```

| Option | Purpose |
|---|---|
| `setKeyProps([group, ] props...)` | override/choose matching key |
| `setUpsertMask(props... \| UpsertMask)` | restrict which columns an upsert may update (and insert, via `UpsertMask.of(...)`) |
| `setIdOnlyAsReference(prop, bool)` / `...All` | treat id-only targets as short association (default true) |
| `setKeyOnlyAsReference(prop)` / `...All` | treat key-only targets as reference (default false) |
| `setAutoIdOnlyTargetChecking(prop)` / `...All` | verify referenced target ids exist (clearer error than FK violation) |
| `setDissociateAction(prop, action)` | runtime override of `@OnDissociate` |
| `setTargetTransferMode(prop, AUTO\|ALLOWED\|NOT_ALLOWED)` | allow moving child to another parent |
| `setDeleteMode(PHYSICAL\|LOGICAL\|AUTO)` | delete flavor for dissociated children |
| `setPessimisticLock(...)` | `select ... for update` during save checks |
| `setOptimisticLock(...)` | user optimistic lock predicate/value |
| `setMaxCommandJoinCount(n)` | tune join depth of internal queries |
| `setDumbBatchAcceptable()` | allow JDBC batches without generated-key return |
| `setConstraintViolationTranslatable(bool)` | toggle translation of constraint violations into typed `SaveException` |
| `addExceptionTranslator(t)` | command-scoped `ExceptionTranslator` (see jimmer-debug) |
| `setTransactionRequired(bool)` | require existing transaction |
| `setDissociationLogicalDeleteEnabled(bool)` | logical-delete dissociated children instead of physical |

## Result Rule

Never re-query after save. Use `getModifiedEntity()`, or:

```java
DomainObjectDetailView view = repository.saveCommand(input)
    .setMode(SaveMode.INSERT_ONLY)
    .execute(DomainObjectDetailView.class)
    .getModifiedView();
```

## QueryReason

SQL log tags extra selects with `QueryReason` — why the SQL-level upsert degraded. Frequent causes: `INTERCEPTOR` (a `DraftInterceptor` is registered — use `DraftPreProcessor` when existence check is not needed), `TRIGGER`, `OPTIMISTIC_LOCK`, `KEY_UNIQUE_CONSTRAINT_REQUIRED`, `NULL_NOT_DISTINCT_REQUIRED`, `NO_MORE_UNIQUE_CONSTRAINTS_REQUIRED`, `UPSERT_NOT_SUPPORTED`, `INVESTIGATE_CONSTRAINT_VIOLATION_ERROR`.

## Decision Tree

- Creating new root only -> `INSERT_ONLY`.
- Idempotent create-if-missing -> `INSERT_IF_ABSENT`.
- Updating known root -> `UPDATE_ONLY`.
- Upsert by key/id -> `UPSERT` (+ `@KeyUniqueConstraint` for atomic SQL upsert; + `setUpsertMask` to protect columns).
- Replace owned child collection -> `REPLACE` + `@OnDissociate` + DB FK action.
- No child deletion -> `MERGE`.
- Full delete/reinsert acceptable -> `VIOLENTLY_REPLACE`.
