---
name: jimmer-save-modes
description: |
  Jimmer SaveMode and AssociatedSaveMode guide for inserts, updates, upserts, key matching, child replacement, and save results.
triggers:
  - "SaveMode"
  - "AssociatedSaveMode"
  - "saveCommand"
  - "VIOLENTLY_REPLACE"
  - "NeitherIdNorKey"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Save Modes

Use for root save modes, child associated modes, key matching, save results, and save-related errors.

## Identity Rules

`@Key` defines natural/business identity for save matching.

- Without `@KeyUniqueConstraint`: select then insert/update; race possible.
- With `@KeyUniqueConstraint` plus DB constraint: atomic upsert path available.
- Composite keys can mix scalar and FK fields.
- Do not add `@Key` on shared one-to-one child without confirming uniqueness semantics.

## SaveMode

| Mode | Behavior |
|---|---|
| `INSERT_ONLY` | insert; error if exists |
| `INSERT_IF_ABSENT` | insert if absent |
| `UPDATE_ONLY` | update; error if missing |
| `UPSERT` | select then insert/update by id/key |
| `NON_IDEMPOTENT_UPSERT` | conflict-based bulk-friendly upsert |

## AssociatedSaveMode

| Mode | Insert | Update | Delete missing |
|---|---|---|---|
| `REPLACE` | yes | yes | yes, needs dissociation rule |
| `MERGE` | yes | yes | no |
| `APPEND` | yes | no | no |
| `APPEND_IF_ABSENT` | skip existing | no | no |
| `UPDATE` | no | yes | no |
| `VIOLENTLY_REPLACE` | yes | yes | delete all + reinsert |

## Save API

```java
sql.saveCommand(domainObject)
    .setMode(SaveMode.UPSERT)
    .setAssociatedModeAll(AssociatedSaveMode.REPLACE)
    .execute();

sql.saveCommand(domainObject)
    .setMode(SaveMode.UPDATE_ONLY)
    .setAssociatedMode(DomainObjectProps.CHILDREN, AssociatedSaveMode.REPLACE)
    .execute();

DomainObjectDetailView view = repository.saveCommand(input)
    .setMode(SaveMode.INSERT_ONLY)
    .execute(DomainObjectDetailView.class)
    .getModifiedView();
```

## Result Rule

Never re-query after save. Use returned entity, result, or modified view.

## Decision Tree

- Creating new root only -> `INSERT_ONLY`.
- Idempotent create-if-missing -> `INSERT_IF_ABSENT`.
- Updating known root -> `UPDATE_ONLY`.
- Upsert by key/id -> `UPSERT`.
- Bulk conflict upsert with key constraint -> `NON_IDEMPOTENT_UPSERT`.
- Replace owned child collection -> `REPLACE` + `@OnDissociate` + DB FK action.
- No child deletion -> `MERGE`.
- Full delete/reinsert acceptable -> `VIOLENTLY_REPLACE`.
