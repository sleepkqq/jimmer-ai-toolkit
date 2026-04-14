---
description: "Build a Jimmer query — STRICT WORKFLOW"
---

# Query Builder — STRICT WORKFLOW

## Step 1: Understand what the user needs

What data? What filters? What result type? Pagination?

## Step 2: Choose approach

The approach is determined solely by what the query needs to return. Scan the project for package structure and naming conventions only. If the correct approach for the query is `@TypedTuple` — use it even if there are no existing `@TypedTuple` examples in the project. Absence of a pattern in the project is never a reason to choose a different approach.

| Situation | Approach |
|---|---|
| Simple query with scalar / FK filters | `createQuery` + `TABLE` |
| Filter on @OneToMany / @ManyToMany collection | `createQuery` + `TABLE_EX` |
| select() contains values that can't be entity properties — window functions, correlated subqueries from other tables, arbitrary SQL expressions | `@TypedTuple` + `createQuery` |
| Window functions (row_number, rank) | `createBaseQuery` + `asBaseTable` |
| Bulk update / delete | `createUpdate` / `createDelete` |

## Step 3: Write the query

### Method order

`.where()` → `.groupBy()` → `.orderBy()` → `.select()` — select is always last.

`.as("name")` does not exist in Jimmer Java DSL — never use it inside `select()`.

### Tables

If a TABLE constant is used more than once in a method, assign it to a local variable first:

```java
var t = ARTICLE_TABLE;   // used multiple times below — extract to variable
var c = COMMENT_TABLE;
```

Use `TABLE` by default. Association navigation on `@ManyToOne` / scalar FKs is implicit — Jimmer auto-joins:

```java
var t = ARTICLE_TABLE;
sql().createQuery(t)
    .where(t.category().name().eqIf(categoryName))  // implicit join on FK
    .where(t.status().eqIf(status))
    .orderBy(t.createdAt().desc())
    .select(t.fetch(ArticleListView.class))
    .fetchPage(page, size);
```

`TABLE_EX` extends `TABLE` with the ability to join `@OneToMany` / `@ManyToMany` collections. Use it as the main table variable when you need to filter on a collection:

```java
var t = ARTICLE_TABLE_EX;
sql().createQuery(t)
    .where(t.tags().id().in(tagIds))
    .where(t.status().eqIf(status))
    .orderBy(t.createdAt().desc())
    .select(t.fetch(ArticleListView.class))
    .fetchPage(page, size);
```

### Dynamic predicates

`eqIf()` / `likeIf()` / `geIf()` — condition is skipped when value is null.

`like(value, mode)` — mode controls wildcard placement:

| LikeMode | SQL pattern |
|---|---|
| `ANYWHERE` (default) | `%value%` |
| `START` | `value%` |
| `END` | `%value` |
| `EXACT` | `value` |

### Return type generic

Add the View generic only when the method returns a View projection. Methods returning `long`, `int`, `void`, `boolean` have no generic:

```java
Page<ArticleListView> findWithFilters(String title, Pageable p);  // View generic
long countByStatus(Status status);                                 // no generic
```

### Generate only what was asked

One method per request, matching exactly what the user described.

## Step 4: Compile

Execute `ls gradlew mvnw 2>/dev/null` as a tool call and wait for the output. The build command is chosen strictly from that output — do not assume a wrapper exists before seeing the result:
- output contains `gradlew` → `./gradlew compileJava` / `./gradlew compileKotlin`
- output contains `mvnw` → `./mvnw compile`
- output is empty → check for `pom.xml` → `mvn compile`, or `build.gradle` → `gradle compileJava` / `gradle compileKotlin`

Fix errors. Done.

---

## Aggregate functions

`count()` is called on the table (all rows) or on a specific field (with optional `distinct`):

```java
var t = BOOK_TABLE;
sql().createQuery(t)
    .select(
        t.count(),                       // COUNT(*)
        t.id().count(/* distinct */ true), // COUNT(DISTINCT id)
        t.price().sum(),
        t.price().min(),
        t.price().max(),
        t.price().avg()
    )
    .execute();
```

For a correlated subquery count (e.g. comments per article):

```java
var t = ARTICLE_TABLE;
var c = COMMENT_TABLE;

var commentCount = sql().createSubQuery(c)
    .where(c.articleId().eq(t.id()))
    .select(c.count());

sql().createQuery(t)
    .orderBy(commentCount.desc())
    .select(t.fetch(ArticleListView.class), commentCount)
    .fetchPage(page, size);
```

## @TypedTuple

Use when `select()` contains values that cannot be expressed as entity properties and therefore cannot go into a .dto View — window functions (`row_number`, `rank`), correlated subqueries from other tables, arbitrary SQL expressions.

Jimmer also has `Tuple2<A, B>`, `Tuple3<A, B, C>`, etc. — they work but give only positional access (`get_1()`, `get_2()`). Always use `@TypedTuple` instead — it produces named fields, is far more readable, and is the correct approach for any multi-value select.

`@TypedTuple` is a plain Java **class** — not an interface, not a record. Fields are `private final`, set via constructor:

```java
@TypedTuple
public class ArticleWithCount {
    private final ArticleListView article;  // always a View DTO, never a raw entity interface
    private final Long commentCount;

    public ArticleWithCount(ArticleListView article, Long commentCount) {
        this.article = article;
        this.commentCount = commentCount;
    }
    // getters
}
```

The field type must match exactly what `select()` fetches. `t.fetch(ArticleListView.class)` returns `ArticleListView` — so the field is `ArticleListView`, not `Article`. Using a raw entity interface here is wrong.

```java
var t = ARTICLE_TABLE;
var c = COMMENT_TABLE;

var commentCount = sql().createSubQuery(c)
    .where(c.articleId().eq(t.id()))
    .select(c.count());

sql().createQuery(t)
    .orderBy(commentCount.desc())
    .select(ArticleWithCountMapper
        .article(t.fetch(ArticleListView.class))
        .commentCount(commentCount))
    .fetchPage(page, size);
```

## Window Functions (createBaseQuery)

`addSelect()` order → `get_1()`, `get_2()` indices.

```java
var t = ARTICLE_TABLE;

var base = sql().createBaseQuery(t)
    .where(t.status().eq(Status.ACTIVE))
    .addSelect(t)
    .addSelect(Expression.numeric().sql(Long.class,
        "row_number() over(order by %e desc)", t.score()))
    .asBaseTable();

sql().createQuery(base)
    .select(RankedMapper
        .item(base.get_1().fetch(viewType))
        .position(base.get_2()))
    .fetchPage(page, size);
```

## Expression.numeric().sql()

Always include type + SQL string. Placeholders: `%e` — column/expression, `%v` — bound value.

## Operators

| Operator | Method | Null-safe variant |
|---|---|---|
| Equal | `.eq()` | `.eqIf()` |
| Not equal | `.ne()` | `.neIf()` |
| Greater / Less | `.gt()` / `.ge()` / `.lt()` / `.le()` | `+If` variants |
| In / Not in | `.in(list)` / `.notIn(list)` | — |
| Like | `.like()` | `.likeIf()` |
| Null check | `.isNull()` / `.isNotNull()` | — |

## Aggregation / Bulk

```java
// Aggregation with groupBy
var t = ARTICLE_TABLE;
sql().createQuery(t)
    .groupBy(t.category().id())
    .select(t.category().id(), t.count())
    .execute();

// Bulk update
var t = ARTICLE_TABLE;
sql().createUpdate(t)
    .where(t.status().eq(Status.DRAFT))
    .set(t.status(), Status.ARCHIVED)
    .execute();
```

## Single results

`fetchOneOrNull()` / `fetchOne()` / `fetchFirstOrNull()`

