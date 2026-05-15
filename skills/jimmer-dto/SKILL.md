---
name: jimmer-dto
description: |
  Jimmer .dto workflow and syntax for Views, Inputs, unsafe Inputs, Specifications, association projections, aliases, and operators.
triggers:
  - "Jimmer DTO"
  - ".dto"
  - "View DTO"
  - "Input DTO"
  - "Specification"
  - "Super QBE"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Jimmer DTO

Use for `.dto` files: Views, Inputs, unsafe Inputs, and Specifications.

## Workflow

1. Read the entity interface and related DTO files.
2. Count DTO names requested by user. Generate exactly those names.
3. Write file at `src/main/dto/{package path}/{EntityName}.dto` unless project uses different convention.
4. Compile with:

```bash
scripts/compile.sh /path/to/project
```

## Choose DTO Type

| User asks for | DTO type |
|---|---|
| Read projection, list/detail response | `View<E>` block without keyword |
| Create/update/save input | `input` |
| Force nullable entity fields non-null | `unsafe input` |
| Query filter object | `specification` |

## Core Syntax

```dto
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
    like(name)
    eq(status)
    ge(createdAt)
}
```

## Scalars

| Syntax | Meaning |
|---|---|
| `#allScalars` | all scalar properties including inherited |
| `#allScalars(this)` | scalars declared on this entity only |
| `#allScalars(BaseType)` | scalars from specific parent |
| `#allScalars?` | all scalars nullable |
| `-field` | exclude after allScalars |
| `field?` | make nullable |
| `field!` | force non-null only where Jimmer allows |
| `field as alias` | rename |

## Associations

```dto
relatedObject {
    id
    name
}

relatedObject? {
    id
    name
}

children* {
    #allScalars
}

id(relatedObject) as relatedObjectId
id(labelObjects) as labelObjectIds

flat(relatedObject) {
    name as relatedObjectName
}
```

## Specification Operators

Use only inside `specification` blocks: `eq`, `ne`, `lt`, `le`, `gt`, `ge`, `like`, `ilike`, `in`, `notIn`, `isNull`, `isNotNull`, `associatedIdEq`, `associatedIdIn`.

## Rules

- Start read Views with `#allScalars`, then subtract sensitive/heavy fields.
- Inputs should include only writable fields.
- Do not manually build entities from input DTOs; use generated `toEntity()` or repository `saveCommand(input)`.
- Import non-standard custom field types inside `.dto` files.
- Nested block: one field per line.
- Enum mapping belongs in DTO only when API shape differs from entity enum.
