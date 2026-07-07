---
name: jimmer-fetchers
description: |
  Jimmer Fetcher and generated-code patterns, View-vs-Fetcher decisions, ReferenceFetchType, field-level config, Input DTO conversion, and N+1 batch loading.
triggers:
  - "Jimmer fetcher"
  - "Fetcher"
  - "ReferenceFetchType"
  - "Input DTO"
  - "generated Jimmer code"
  - "N+1"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Fetchers

Use for runtime field selection, generated classes, View-vs-Fetcher decisions, and N+1 prevention.

## View vs Fetcher

| Need | Use |
|---|---|
| Stable API/read model | `.dto` View |
| Save/write payload | `.dto` Input |
| Runtime/dynamic field set | Fetcher |
| GraphQL-style selection | Fetcher |

Default to View DTOs. Use Fetcher only when fields vary at runtime.

## Input DTO Rule

`Input<E>` generates `toEntity()`. Do not manually build entities from input DTOs.

```java
DomainObject domainObject = input.toEntity();
repository.save(domainObject);
```

## Fetcher API

```java
DOMAIN_OBJECT_FETCHER
    .allScalarFields()
    .relatedObject(RELATED_OBJECT_FETCHER.name());
```

Use generated `Fetchers` constants. Do not use `$` references in Java.

| Method | Includes |
|---|---|
| `allScalarFields()` | non-association properties |
| `allReferenceFields()` | FK associations id-only |
| `allTableFields()` | scalars + references |

### Reference fetch strategy

`ReferenceFetchType` per reference association: `AUTO` (default), `SELECT` (separate batched query), `JOIN_IF_NO_CACHE`, `JOIN_ALWAYS` (fetch via join in main query):

```java
BOOK_FETCHER.allScalarFields()
    .store(ReferenceFetchType.JOIN_ALWAYS, BOOK_STORE_FETCHER.allScalarFields());
```

In `.dto` files the same is `!fetchType(JOIN_ALWAYS)`.

### Field-level config

Collection/recursive fields accept lambda config: `filter(args -> args.orderBy(...))`, `batch(n)`, `limit(limit, offset)`, `depth(n)` / `recursive(...)` for self-associations.

## Generated Code

| Generated class | Purpose |
|---|---|
| `DomainObjectDraft` | mutable builder |
| `DomainObjectTable` / `DomainObjectTableEx` | typed query tables |
| `DomainObjectProps` | typed prop constants |
| `Tables` | table constants |
| `Fetchers` | fetcher constants |
| `Immutables` | entity factory only |
| `*View`, `*Input`, `*Spec` | DTO classes |

## N+1

Jimmer batch-loads associations (defaults: batch 128, list batch 16). Tune in config when needed:

```yaml
jimmer:
  default-batch-size: 128
  default-list-batch-size: 16
```
