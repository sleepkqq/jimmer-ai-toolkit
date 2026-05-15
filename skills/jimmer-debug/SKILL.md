---
name: jimmer-debug
description: |
  Jimmer debugging workflow for save mode, dissociation, key, fetcher/view loading, optimistic lock, and generated-code errors.
triggers:
  - "Jimmer error"
  - "NeitherIdNorKey"
  - "CannotDissociateTarget"
  - "UnloadedPropertyException"
  - "OptimisticLockError"
  - "QueryReason"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Jimmer Debug

Use for Jimmer save/query/runtime/generated-code errors.

## Workflow

1. Collect exception class/message, entity, save/query code, SQL logs, and `QueryReason` if present.
2. Match quick table.
3. Inspect affected entity path, especially `exportedPath` in `SaveException`.
4. Check `@Key`, `@KeyUniqueConstraint`, `@OnDissociate`, nullability, FK constraints, and loaded properties.
5. Apply minimal fix and compile:

```bash
scripts/compile.sh /path/to/project
```

## Quick Fix Table

| Error | First check |
|---|---|
| `NeitherIdNorKey` | child needs `@Id`, `@Key`, or `VIOLENTLY_REPLACE` |
| `CannotDissociateTarget` | missing `@OnDissociate` and matching DB FK action |
| `NotUnique` on one-to-one | wrong `@Key`/unique semantics on child |
| `KEY_UNIQUE_CONSTRAINT_REQUIRED` | add `@KeyUniqueConstraint` and DB unique constraint |
| `UnloadedPropertyException` | add field to View/Fetcher or guard with `ImmutableObjects.isLoaded()` |
| `OptimisticLockError` | include `@Version`, re-read, or handle conflict |

## Common Diagnoses

`NeitherIdNorKey`: save mode must identify child records. Add natural `@Key`, pass id, or use `AssociatedSaveMode.VIOLENTLY_REPLACE` for delete-all/reinsert semantics.

`CannotDissociateTarget`: `REPLACE` found DB children absent from new collection. Add `@OnDissociate(DissociateAction.DELETE)` or `SET_NULL` and align DB FK action.

`UnloadedPropertyException`: generated immutable object has unloaded field. Query must fetch it via View/Fetcher, or code must test loaded state.

`OptimisticLockError`: partial update missing or stale version. Include version field in update input/view where needed.

## Rule

Fix root annotation/query/save-mode mismatch. Do not hide Jimmer errors with broad catch blocks or re-query loops.
