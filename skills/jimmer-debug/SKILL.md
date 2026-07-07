---
name: jimmer-debug
description: |
  Jimmer debugging workflow for save mode, dissociation, key, fetcher/view loading, optimistic lock, constraint violations, ExceptionTranslator, and generated-code errors.
triggers:
  - "Jimmer error"
  - "NeitherIdNorKey"
  - "CannotDissociateTarget"
  - "UnloadedPropertyException"
  - "OptimisticLockError"
  - "ExceptionTranslator"
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

`SaveException` subtypes (`SaveException.NotUnique` etc.):

| Error | First check |
|---|---|
| `NeitherIdNorKey` | child needs `@Id`, `@Key`, or `VIOLENTLY_REPLACE` |
| `CannotDissociateTarget` | missing `@OnDissociate` and matching DB FK action |
| `NotUnique` | key/unique constraint conflict — catch or translate, or switch to `UPSERT` |
| `NoKeyProp` / `NoVersion` | save matched by key without `@Key`, or optimistic mode without `@Version` |
| `IllegalTargetId` | referenced association id does not exist (`setAutoIdOnlyTargetChecking`) |
| `TargetIsNotTransferable` | child moved to another parent — `setTargetTransferMode(prop, ALLOWED)` |
| `IncompleteProperty` | partial embeddable/composite value in save |
| `OptimisticLockError` | include `@Version`, re-read, or handle conflict |
| `KEY_UNIQUE_CONSTRAINT_REQUIRED` (QueryReason) | add `@KeyUniqueConstraint` and DB unique constraint |
| `UnloadedPropertyException` | add field to View/Fetcher or guard with `ImmutableObjects.isLoaded()` |

## Common Diagnoses

`NeitherIdNorKey`: save mode must identify child records. Add natural `@Key`, pass id, or use `AssociatedSaveMode.VIOLENTLY_REPLACE` for delete-all/reinsert semantics.

`CannotDissociateTarget`: `REPLACE` found DB children absent from new collection. Add `@OnDissociate(DissociateAction.DELETE)` or `SET_NULL` and align DB FK action.

`UnloadedPropertyException`: generated immutable object has unloaded field. Query must fetch it via View/Fetcher, or code must test loaded state.

`OptimisticLockError`: partial update missing or stale version. Include version field in update input/view where needed.

Unexpected extra SELECTs before save: read `QueryReason` in SQL log. `INTERCEPTOR` means a `DraftInterceptor` disabled SQL-level upsert — use `DraftPreProcessor` if existence check not needed. `INVESTIGATE_CONSTRAINT_VIOLATION_ERROR` means Jimmer re-queried to translate a constraint violation into a typed error.

## ExceptionTranslator

Translate raw constraint violations into domain errors instead of catching SQL exceptions:

```java
@ApplicationScoped // or @Component; also: sqlClient builder / per-command addExceptionTranslator
public class NotUniqueTranslator implements ExceptionTranslator<SaveException.NotUnique> {
    @Override
    public Exception translate(SaveException.NotUnique ex, Args args) {
        if (ex.isMatched(DomainObjectProps.NAME)) {
            return new ConflictException("Name already taken: " + ex.getValue(DomainObjectProps.NAME));
        }
        return null; // not handled — try other translators
    }
}
```

Generic type argument is mandatory. Registration: per save command (highest priority), sql client builder, or DI bean.

## Rule

Fix root annotation/query/save-mode mismatch. Do not hide Jimmer errors with broad catch blocks or re-query loops.
