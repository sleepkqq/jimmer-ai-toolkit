---
name: jimmer-dto
description: |
  Jimmer .dto language workflow and syntax for Views, Inputs, Specifications, input handle modes (fixed/static/dynamic/fuzzy), fold/flat, alias groups, configurations, and enum mappings.
triggers:
  - "Jimmer DTO"
  - ".dto"
  - "View DTO"
  - "Input DTO"
  - "Specification"
  - "input handle mode"
  - "dynamic input"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Jimmer DTO

Use for `.dto` files: Views, Inputs, and Specifications.

## Workflow

1. Read the entity interface and related DTO files.
2. Count DTO names requested by user. Generate exactly those names.
3. Write file at `src/main/dto/{entity package path}/{EntityName}.dto`. File name must match the entity simple name.
4. Compile with:

```bash
scripts/compile.sh /path/to/project
```

Editing only `.dto` files does not trigger incremental recompilation — force a rebuild.

## Choose DTO Type

| User asks for | DTO type |
|---|---|
| Read projection, list/detail response | plain block (implements `View<E>`) |
| Create/update/save input | `input` |
| Force nullable entity fields non-null in Input | `unsafe input` |
| Query filter object (Super QBE) | `specification` |

## Core Syntax

```dto
export com.app.model.DomainObject -> package com.app.model.dto

DomainObjectView {
    #allScalars
    -internalNotes
    relatedObject {
        id
        name
    }
}

input DomainObjectCreateInput {
    name
    id(relatedObject) as relatedObjectId
}

specification DomainObjectSpec {
    like/i(name)
    eq(status)
    ge(createdAt)
    associatedIdEq(relatedObject)
}
```

## Macros

| Syntax | Meaning |
|---|---|
| `#allScalars` | all scalar props including inherited |
| `#allScalars(this)` | scalars declared on this entity only |
| `#allScalars(BaseType)` | scalars from specific supertype |
| `#allScalars?` | all included scalars nullable |
| `#allScalars!` | force non-null (unsafe input) |

Props annotated `@ExcludeFromAllScalars` in the entity are skipped by `#allScalars`.

## Prop Syntax

| Syntax | Meaning |
|---|---|
| `-field` | exclude after a macro |
| `field?` | make nullable |
| `field!` | force non-null (only in `unsafe input`) |
| `field as alias` | rename |
| `id(assoc) as assocId` | FK id projection (alias mandatory for list assoc: `id(items) as itemIds`) |
| `flat(assoc) { name as assocName }` | inline association/embeddable fields into parent |
| `fold(group) { name  edition }` | inverse of flat: group own scalar props into a nested object; `fold(x)?` makes group nullable; nestable, combinable with flat |
| `children*` | recursive fetch of self-association |
| `prop -> { CONST: "value", ... }` | enum value mapping (string or int) |
| `extraProp: Type = default` | user prop with literal default; `import` custom types |
| `as(^ -> prefix) { ... }` / `as(suffix$ -> ) { ... }` | alias group: batch-rename props inside block |
| `implements a.b.Iface` | on type or prop body |

DTO types and props accept passthrough annotations (`@com.x.Anno(...)`) and doc comments.

## Input Handle Modes

Type-level or per-prop modifiers, `input` only: `fixed`, `static`, `dynamic`, `fuzzy`.

| Mode | Prop absent in JSON | Prop null in JSON |
|---|---|---|
| `fixed` | HTTP 400 (must be explicit) | set DB column to null |
| `static` (default) | treated as null | set DB column to null |
| `dynamic` | prop not loaded — column untouched | set DB column to null |
| `fuzzy` | prop not loaded | prop not loaded (can never null out) |

`dynamic`/`fuzzy` give PATCH semantics: unspecified fields are not updated. Prefer `dynamic input` for partial-update endpoints.

## Specification Functions

Only inside `specification`: `eq`, `ne`, `lt`, `le`, `gt`, `ge`, `like`, `notLike`, `null`, `notNull`, `valueIn`, `valueNotIn`, `associatedIdEq`, `associatedIdNe`, `associatedIdIn`, `associatedIdNotIn`.

- `like` flags: `like/i` insensitive, `like/^` prefix match, `like/$` suffix match, combinable (`like/i^`).
- Multi-prop OR form allowed for `eq`, `like`, `null`, `notNull`, `valueIn`, `associatedIdEq`, `associatedIdIn`: `like/i(firstName, lastName) as name`. Alias mandatory with multiple args.
- Alias mandatory for `ne`, `notLike`, `valueIn`, `valueNotIn`.
- Use `associatedIdEq(assoc)` for FK filters; plain `id(assoc)` is forbidden in specification.
- Null args are skipped at query time (dynamic predicates).

## Configurations

Annotation-like options on association props (mainly Views):

| Config | Purpose |
|---|---|
| `!where(a = 1 and b <> 'x')` | filter associated rows (SQL-ish predicate, `is null` / `is not null` supported) |
| `!orderBy(name asc, createdAt desc)` | sort associated rows |
| `!filter(FilterClass)` | custom `RecursionStrategy`-style field filter class |
| `!recursion(StrategyClass)` | custom recursion strategy for `*` props |
| `!fetchType(SELECT \| JOIN_IF_NO_CACHE \| JOIN_ALWAYS \| AUTO)` | reference association fetch strategy |
| `!limit(n[, offset])` | limit associated collection |
| `!batch(n)` | batch size for this association load |
| `!depth(n)` | recursion depth limit for `*` props |

## Rules

- Start read Views with `#allScalars`, then subtract sensitive/heavy fields.
- Inputs include only writable fields; never manually map input to entity — use generated `toEntity()` or `saveCommand(input)`.
- Nested block: one field per line.
- Enum mapping belongs in DTO only when API shape differs from entity enum.
