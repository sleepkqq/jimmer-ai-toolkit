---
name: jimmer-query
description: |
  Typed Jimmer query workflow for table selection, dynamic predicates, pagination, aggregates, typed tuples, window functions, and bulk operations.
triggers:
  - "Jimmer query"
  - "createQuery"
  - "TABLE_EX"
  - "@TypedTuple"
  - "fetchPage"
  - "createUpdate"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Jimmer Query

Use for typed Jimmer queries, filters, pagination, aggregates, tuple projections, window functions, and bulk update/delete.

## Workflow

1. Clarify data shape, filters, sorting, pagination, and return type.
2. Run project scan when package/style unknown:

```bash
scripts/scan-project.sh /path/to/project
```

3. Choose approach from table below.
4. Write only query methods called by current task.
5. Compile:

```bash
scripts/compile.sh /path/to/project
```

## Approach Table

| Need | Approach |
|---|---|
| Scalar/FK filters | `createQuery` + `TABLE` |
| Filter on `@OneToMany` / `@ManyToMany` | `createQuery` + `TABLE_EX` |
| Return entity/view | `.select(t.fetch(ViewClass.class))` or `.select(t)` |
| Aggregate/subquery/expression not entity property | `@TypedTuple` + mapper |
| Window functions | `createBaseQuery` + `asBaseTable` |
| Bulk update/delete | `createUpdate` / `createDelete` |

## Java DSL Rules

- Method order: `.where()` -> `.groupBy()` -> `.orderBy()` -> `.select()`.
- `select()` is last.
- `.as("name")` does not exist inside Java DSL `select()`.
- Extract a table variable when a table constant is used more than once.
- `eqIf`, `likeIf`, `geIf`, etc. skip null values.
- Use `LikeMode.ANYWHERE`, `START`, `END`, `EXACT` intentionally.

```java
var t = DOMAIN_OBJECT_TABLE;
return sql().createQuery(t)
    .where(t.relatedObject().name().eqIf(relatedObjectName))
    .where(t.status().eqIf(status))
    .orderBy(t.createdAt().desc())
    .select(t.fetch(DomainObjectListView.class))
    .fetchPage(page, size);
```

Collection filter:

```java
var t = DOMAIN_OBJECT_TABLE_EX;
return sql().createQuery(t)
    .where(t.labelObjects().id().in(labelObjectIds))
    .select(t.fetch(DomainObjectListView.class))
    .fetchPage(page, size);
```

## Typed Tuple Rule

Use `@TypedTuple` when `select()` contains non-entity values: counts, ranks, expressions, correlated subqueries, SQL expressions. Keep tuple mapper near repository/query code unless project has convention.

## Kotlin Note

In Kotlin DSL, `table` supports associations without `TableEx`; use nullable operators like ``eq?`` and `KClass<V>` for view type generics.
