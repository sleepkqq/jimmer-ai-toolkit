# Jimmer DTO Language Reference

## DTO types

| Keyword | Interface | Purpose |
|---|---|---|
| (none) | `View<E>` | Read-only projection |
| `input` | `Input<E>` | Write / save |
| `unsafe input` | `Input<E>` | Write — allows forcing nullable entity fields to non-null |
| `specification` | `Specification<E>` | Query filter (Super QBE) |

## #allScalars variants

| Syntax | Includes |
|---|---|
| `#allScalars` | All scalar properties including inherited |
| `#allScalars(this)` | Only scalars defined on this entity (no inherited) |
| `#allScalars(BaseEntity)` | Scalars from a specific parent type only |
| `#allScalars(Type1, Type2)` | Scalars from multiple specific types |
| `#allScalars?` | All scalars, all made nullable |

## Property modifiers

```
field?          // make nullable
field!          // force non-null (only for auto-increment IDs or inside unsafe input)
-field          // exclude (after #allScalars)
field as alias  // rename
```

## Bulk rename with as()

```
as(^ -> Prefix)         // add prefix to all properties
as(^OldPrefix ->)       // remove prefix
as(^Old -> ^New)        // replace prefix
as($ -> Suffix)         // add suffix
as($OldSuffix ->)       // remove suffix
as($Old -> $New)        // replace suffix
```

## Associations

```
// Nested with explicit shape — each field on its own line
category {
    id
    name
}

// Force-nullable association
category? {
    id
    name
}

// Recursive (tree)
children* {
    #allScalars
}

// Extract FK id only — @ManyToOne
id(category) as categoryId

// Extract FK ids — @ManyToMany
id(tags) as tagIds

// Flatten nested object into parent
flat(author) {
    name as authorName
    email as authorEmail
}
```

## Custom fields (non-entity properties)

```
input BookInput {
    #allScalars
    remark: String
    labels: List<String>
}
```

Requires `import` for non-standard types:

```
import java.time.LocalDate

input BookInput {
    #allScalars
    customDate: LocalDate
}
```

## Enum mapping

```
ArticleView {
    #allScalars
    status -> {
        DRAFT: 0
        PUBLISHED: 1
        ARCHIVED: 2
    }
}
```

## Interface implementation

```
input BookInput implements Saveable<Book> {
    #allScalars
}
```

## Specification operators (Super QBE)

Used only inside `specification` blocks.

### Comparison

```
specification ArticleSpec {
    eq(status)              // =
    ne(status)              // !=
    gt(price)               // >
    ge(price)               // >=
    lt(price)               // <
    le(price)               // <=
}
```

Range filter with aliased names:

```
specification ArticleSpec {
    ge(price) as minPrice
    le(price) as maxPrice
}
```

### String matching

```
specification ArticleSpec {
    like(title)             // LIKE %value%
    like/i(title)           // ILIKE %value% (case-insensitive)
    like/^(title)           // LIKE value%
    like/$(title)           // LIKE %value
    like/i^(title)          // ILIKE value%
    notLike(title)          // NOT LIKE %value%
}
```

Multiple fields — OR logic:

```
specification ArticleSpec {
    like/i(firstName, lastName) as authorName
}
```

### Null checks

```
specification ArticleSpec {
    null(deletedAt)         // boolean — true → IS NULL
    notNull(deletedAt)      // boolean — true → IS NOT NULL
}
```

### Collection

```
specification ArticleSpec {
    valueIn(status)         // IN (...)
    valueNotIn(status)      // NOT IN (...)
}
```

### Association ID filters

```
specification ArticleSpec {
    associatedIdEq(category)       // category.id = ?
    associatedIdNe(category)       // category.id != ?
    associatedIdIn(category)       // category.id IN (...)
    associatedIdNotIn(category)    // category.id NOT IN (...)
}
```
