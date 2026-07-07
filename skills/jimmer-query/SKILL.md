---
name: jimmer-query
description: |
  Typed Jimmer query workflow for table selection, dynamic predicates, pagination, aggregates, typed tuples, base tables, window functions, and bulk operations.
triggers:
  - "Jimmer query"
  - "createQuery"
  - "TABLE_EX"
  - "@TypedTuple"
  - "fetchPage"
  - "createBaseQuery"
  - "createUpdate"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Jimmer Query

Use for typed Jimmer queries, filters, pagination, aggregates, tuple projections, base tables/window functions, and bulk update/delete.

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
| Aggregate/subquery/expression not entity property | `@TypedTuple` class or `Tuple2..TupleN` |
| Window functions / reuse of query result columns | `createBaseQuery` + `asBaseTable` |
| Nonstandard join condition | `WeakJoin` (`t.asTableEx().weakJoin(...)`) |
| Bulk update/delete | `createUpdate` / `createDelete` |

## Java DSL Rules

- Method order: `.where()` -> `.groupBy()` -> `.orderBy()` -> `.select()`. `select()` is last.
- `.as("name")` does not exist inside Java DSL `select()`.
- Extract a table variable when a table constant is used more than once.
- Dynamic predicates: `eqIf`, `likeIf`, `geIf`, ... skip null **and empty string** operands; `whereIf(cond, ...)` and `orderByIf(cond, ...)` for conditional clauses.
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

Subquery: `sql().createSubQuery(otherTable)` inside predicates (`exists`, `in`, scalar compare).

## Base Tables (window functions, column reuse)

`createBaseQuery` builds a reusable inner query; `asBaseTable()` exposes it as a typed table with `get_1()`, `get_2()`, ... Fetchers still work on entity columns.

```java
var store = DOMAIN_OBJECT_TABLE;
BaseTable2<DomainObjectTable, NumericExpression<Integer>> baseTable = sql()
    .createBaseQuery(store)
    .addSelect(store)
    .addSelect(Expression.numeric().sql(
        Integer.class, "dense_rank() over(order by %e desc)", someExpression))
    .asBaseTable();

return sql().createQuery(baseTable)
    .where(baseTable.get_2().le(rankLimit))
    .select(baseTable.get_1().fetch(DomainObjectListView.class))
    .fetchPage(page, size);
```

Base queries support unions and pagination over the union.

## Typed Tuple Rule

Use `@TypedTuple` when `select()` contains non-entity values: counts, ranks, expressions, correlated subqueries. Keep tuple mapper near repository/query code unless project has convention.

## Kotlin Note

In Kotlin DSL, `table` supports collection joins without `TableEx`; null-safe operators spelled ``eq?``, ``like?``, etc.; view type passed as `KClass<V>`. See `jimmer-kotlin`.
