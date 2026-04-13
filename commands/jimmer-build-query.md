---
description: "Build a complex Jimmer query with typed DSL — createQuery, subQuery, window functions, DTO language"
---

# Query Builder

## Key Rules

- **Method order:** `.where()` → `.groupBy()` → `.orderBy()` → `.select()` → `.fetchPage()`. **select() ALWAYS LAST**
- **Tables:** `ARTICLE_TABLE` from `Tables` (never `ArticleTable.$`). For `@OneToMany`/`@ManyToMany` use `ARTICLE_TABLE_EX`
- **Dynamic predicates:** `eqIf()`/`likeIf()`/`geIf()` — skip when null
- **like()** adds `%` automatically — never add `%` manually. Case-insensitive: `ilike()`
- **Joins are implicit** — Jimmer auto-JOINs on FK/association navigation
- **Multi-column results** — use `@TypedTuple` + generated Mapper, never raw `Tuple2`/`Tuple3`

## Operators

| Operator | Method | Dynamic (null-safe) |
|---|---|---|
| Equal | `.eq()` | `.eqIf()` |
| Not equal | `.ne()` | `.neIf()` |
| Greater/Less | `.gt()` / `.ge()` / `.lt()` / `.le()` | `+If` variants |
| In / Not in | `.in(list)` / `.notIn(list)` | — |
| Like | `.like()` | `.likeIf()` |
| Null check | `.isNull()` / `.isNotNull()` | — |

---

## createQuery

```java
var t = ARTICLE_TABLE;
sql.createQuery(t)
    .where(t.status().eqIf(statusFilter))
    .where(t.title().likeIf(titleFilter, LikeMode.ANYWHERE))
    .orderBy(t.createdAt().desc())
    .select(t.fetch(viewType))
    .fetchPage(page, size);
```

## Subqueries

```java
var t = ARTICLE_TABLE_EX;  // TableEx for @ManyToMany navigation
sql.createQuery(t)
    .where(t.id().in(
        sql.createSubQuery(t)
            .where(t.tags().id().in(tagIds))
            .select(t.id())
    ))
    .select(t.fetch(viewType))
    .fetchPage(page, size);
```

## @TypedTuple — Multi-Column Results

When query returns entity + computed values, define a `@TypedTuple` class — Jimmer generates `*Mapper` with fluent builder.

```java
@TypedTuple
public class RatedArticle {
    private final ArticleListView article;
    private final Double avgRating;
    private final Long commentCount;
    // constructor + getters
}

// Mapper fields match constructor order. Use in .select():
.select(RatedArticleMapper
    .article(t.fetch(ArticleListView.class))
    .avgRating(avgRatingExpr)
    .commentCount(commentCountExpr)
)
```

## Window Functions (createBaseQuery)

`createBaseQuery` + `addSelect` + `asBaseTable` for window functions and multi-column projections.

**`addSelect()` order determines `get_1()`, `get_2()`, `get_3()` indices on the base table.**

```java
var t = ORDER_TABLE;

// Step 1: base query with addSelect in order
var base = sql.createBaseQuery(t)
    .where(t.status().eq(Status.ACTIVE))
    .addSelect(t)                          // get_1() → entity
    .addSelect(t.total())                  // get_2() → total
    .addSelect(Expression.numeric().sql(   // get_3() → rank
        Long.class,
        "row_number() over(order by %e desc, %e asc)",
        t.total(), t.id()))
    .asBaseTable();

// Step 2: query the base table, map with TypedTuple Mapper
sql.createQuery(base)
    .select(RankedOrderMapper
        .order(base.get_1().fetch(OrderListView.class))
        .total(base.get_2())
        .position(base.get_3()))
    .fetchPage(page, size);
```

## Expression.numeric().sql()

**Always include `.sql()` with type + SQL string.** `Expression.numeric()` alone is incomplete.

```java
// Scalar subquery as expression
Expression.numeric().sql(Double.class,
    "(SELECT AVG(r.rating) FROM review r WHERE r.recipe_id = %e)", t.id())

// Window function
Expression.numeric().sql(Long.class,
    "row_number() over(order by %e desc)", t.score())
```

Placeholders: `%e` — column/expression, `%v` — bound parameter.

## Aggregation / Bulk Operations

```java
// Aggregation
sql.createQuery(t).groupBy(t.category().id())
    .select(t.category().id(), t.count()).execute();

// Bulk update
sql.createUpdate(t).where(t.status().eq(Status.DRAFT))
    .set(t.status(), Status.ARCHIVED).execute();

// Bulk delete
sql.createDelete(t).where(t.status().eq(Status.ARCHIVED)).execute();
```

## Single Results

`query.fetchOneOrNull()` (nullable), `query.fetchOne()` (throws), `query.fetchFirstOrNull()` (first of many).

---

# DTO Language Reference

One `.dto` file per entity. Export declaration + DTO definitions:

```
export com.example.entity.Article
    -> package com.example.entity.dto

ArticleListView {
    id
    title
    createdAt
    category { id; name }
}

input ArticleCreateInput {
    title
    content
    id(category) as categoryId     // @ManyToOne — single ID
    id(tags) as tagIds             // @ManyToMany — List<ID> (always id(), NOT ids())
}

specification ArticleSpec {
    like/i(title)
    ge(createdAt)
    eq(status)
}
```

## Property Syntax

```
#allScalars              // all non-association properties
-content                 // exclude field
title as articleTitle    // rename/alias
category? { id; name }  // force nullable
id(category) as catId   // @ManyToOne — single ID
id(tags) as tagIds      // @ManyToMany — List<ID>
flat(author) { name as authorName }  // flatten nested
children* { #allScalars }            // recursive (tree)
```
