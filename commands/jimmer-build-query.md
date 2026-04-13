---
description: "Build a complex Jimmer query with typed DSL — createQuery, subQuery, window functions, DTO language"
---

# Query Builder

Build typed Jimmer queries using the patterns below.

## Key Rules

- Java tables: use `ARTICLE_TABLE` from generated `Tables` — never `ArticleTable.$`
- Java collection joins (`@OneToMany`/`@ManyToMany`): use `ARTICLE_TABLE_EX` — `Table` only has FK navigation
- Kotlin: `table` in query DSL supports all associations, no TableEx needed
- `like()` adds `%` automatically (LikeMode.ANYWHERE) — never add `%` manually
- Use generic `viewType` parameter — never hardcode View classes
- Dynamic predicates: Kotlin `eq?`/`like?`, Java `eqIf()`/`likeIf()`

## Process

1. **Understand data requirements** — what data, which entities, filters, sorting, pagination, window functions?
2. **Choose approach:** `createQuery` (basic), `createSubQuery` (nested), `createBaseQuery` + `asBaseTable` (window functions), `createUpdate`/`createDelete` (bulk)
3. **Build query** with typed table expressions, dynamic predicates, and View/Fetcher for result shaping
4. **Generate code** in the user's language (Kotlin or Java)

---

# Query Reference

## Query Method Order (CRITICAL)

Methods MUST be called in this order:

1. `createQuery(table)`
2. `.where(...)` — filters
3. `.groupBy(...)` — grouping (if needed)
4. `.having(...)` — group filters (if needed)
5. `.orderBy(...)` — sorting
6. `.select(...)` — projection (**ALWAYS LAST** before terminal)
7. `.fetchPage()` / `.execute()` — terminal operation

```java
// WRONG — select before orderBy
sql.createQuery(t).select(t).orderBy(t.createdAt().desc())

// CORRECT — orderBy before select
sql.createQuery(t).orderBy(t.createdAt().desc()).select(t)
```

---

## createQuery

```kotlin
sql.createQuery(Article::class) {
    where(table.status eq ArticleStatus.PUBLISHED)
    orderBy(table.createdAt.desc())
    select(table.fetch(ArticleListView::class))
}.fetchPage(page, size)
```

```java
var t = ARTICLE_TABLE;
sql.createQuery(t)
    .where(t.status().eq(ArticleStatus.PUBLISHED))
    .orderBy(t.createdAt().desc())
    .select(t.fetch(ArticleListView.class))
    .fetchPage(page, size);
```

## Where Clauses

```kotlin
// AND — multiple predicates
where(table.status eq ArticleStatus.PUBLISHED, table.createdAt ge startDate)

// OR
where(or(table.status eq ArticleStatus.DRAFT, table.status eq ArticleStatus.REVIEW))

// Dynamic (applied only if non-null)
where(table.title `like?` titleFilter)
where(table.status `eq?` statusFilter)
```

```java
.where(t.title().likeIf(titleFilter, LikeMode.ANYWHERE))
.where(t.status().eqIf(statusFilter))
```

| Operator | Kotlin | Java |
|---|---|---|
| Equal | `eq` / `eq?` | `.eq()` / `.eqIf()` |
| Not equal | `ne` / `ne?` | `.ne()` / `.neIf()` |
| Greater than | `gt` / `gt?` | `.gt()` / `.gtIf()` |
| Greater or equal | `ge` / `ge?` | `.ge()` / `.geIf()` |
| Less than | `lt` / `lt?` | `.lt()` / `.ltIf()` |
| Less or equal | `le` / `le?` | `.le()` / `.leIf()` |
| Between | `between(a, b)` | `.between(a, b)` |
| In / Not in | `valueIn(list)` | `.in(list)` / `.notIn(list)` |
| Null check | `isNull()` / `isNotNull()` | `.isNull()` / `.isNotNull()` |
| Like | `like` / `like?` | `.like()` / `.likeIf()` |

All `*If` methods (Java) and `*?` operators (Kotlin) skip the predicate when the value is null.

LikeModes: `EXACT`, `START` (value%), `END` (%value), `ANYWHERE` (%value%, default). Case-insensitive: `ilike()`.

## Joins

```kotlin
// Implicit — Jimmer auto-JOINs on FK navigation
where(table.category.name eq "Technology")

// Explicit
val authorTable = table.join(Article::author)
val categoryTable = table.outerJoin(Article::category)
```

```java
// TableEx for @OneToMany/@ManyToMany — Table only has FK navigation
var t = ARTICLE_TABLE_EX;
sql.createQuery(t)
    .where(t.tags().id().eqIf(tagId))  // tags is @ManyToMany — needs TableEx
```

## Pagination

```kotlin
// Recommended
query.fetchPage(pageIndex, pageSize)
// page.rows, page.totalRowCount, page.totalPageCount

// Manual
query.limit(pageSize, offset.toLong()).execute()
```

## Aggregation

```kotlin
sql.createQuery(Article::class) {
    groupBy(table.category.id)
    select(table.category.id, count(table))
}.execute()
```

## Subqueries

```java
// Subquery in WHERE — use the same TableEx variable throughout
var t = ARTICLE_TABLE_EX;
sql.createQuery(t)
    .where(tagIds == null || tagIds.isEmpty() ? null :
        t.id().in(
            sql.createSubQuery(t)
                .where(t.tags().id().in(tagIds))
                .select(t.id())
        )
    )
    .select(t.fetch(viewType))
    .fetchPage(page, size);
```

## @TypedTuple + TupleMapper — Multi-Column Results

When a query returns entity + computed values (ratings, rankings, counts), use `@TypedTuple` to get a typed result object instead of raw `Tuple2`/`Tuple3`.

### Step 1: Define the tuple class

```java
@TypedTuple
public class RatedRecipe {
    private final RecipeListView recipe;
    private final Double avgRating;

    public RatedRecipe(RecipeListView recipe, Double avgRating) {
        this.recipe = recipe;
        this.avgRating = avgRating;
    }
    // getters
}
```

Jimmer generates `RatedRecipeMapper` with a fluent builder.

### Step 2: Use in query

```java
.select(RatedRecipeMapper
    .recipe(t.fetch(RecipeListView.class))
    .avgRating(avgRatingExpression)
)
.fetchPage(page, size);
```

### Full example with window function

```java
var baseOrder = sql.createBaseQuery(t)
    .where(t.status().eq(OrderStatus.COMPLETED))
    .addSelect(t)
    .addSelect(Expression.numeric().sql(Long.class,
        "row_number() over(order by %e desc)", t.total()))
    .asBaseTable();

sql.createQuery(baseOrder)
    .select(RankedOrderMapper
        .order(baseOrder.get_1().fetch(OrderListView.class))
        .position(baseOrder.get_2())
    )
    .fetchPage(page, pageSize);
```

**`Expression.numeric().sql()` requires the `.sql()` call with a SQL string:**

```java
// WRONG — incomplete, returns nothing useful
Expression.numeric()

// CORRECT — must call .sql() with SQL string and type
Expression.numeric().sql(Long.class, "row_number() over(order by %e desc)", t.total())
Expression.numeric().sql(Double.class, "(SELECT AVG(r.rating) FROM review r WHERE r.recipe_id = %e)", t.id())
```

Expression placeholders: `%e` — column/expression, `%v` — bound parameter.

## Bulk Update / Delete

```kotlin
sql.createUpdate(Article::class) {
    where(table.status eq ArticleStatus.DRAFT)
    set(table.status, ArticleStatus.ARCHIVED)
}.execute()

sql.createDelete(Article::class) {
    where(table.status eq ArticleStatus.ARCHIVED)
}.execute()
```

## Fetching Single Results

```kotlin
query.fetchOneOrNull()     // nullable
query.fetchOne()           // throws if not found
query.fetchFirstOrNull()   // first of many
```

---

# DTO Language Reference

## File Location & Export

```
// src/main/dto/Article.dto
export com.example.entity.Article
    -> package com.example.entity.dto
```

One `.dto` file per entity.

## View / Input / Specification

```
ArticleListView {
    id
    title
    createdAt
    category { id; name }
}

ArticleDetailView {
    #allScalars
    category { id; name }
    comments { id; content; createdAt }
}

input ArticleCreateInput {
    title
    content
    id(category) as categoryId        // @ManyToOne — single ID
    id(tags) as tagIds                // @ManyToMany — List<ID>
}

input ArticleUpdateInput {
    id
    title
    content
    id(category) as categoryId
    id(tags) as tagIds
    version
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
id(category) as catId   // @ManyToOne FK — single ID
id(tags) as tagIds      // @ManyToMany — List<ID> (NOT ids(), always id())
flat(author) { name as authorName }  // flatten nested
children* { #allScalars }            // recursive (tree)
children*[depth=3] { #allScalars }   // recursive with limit
```
