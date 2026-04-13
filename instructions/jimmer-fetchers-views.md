# Jimmer Fetchers, Views, and DTOs

## Overview

Jimmer provides three mechanisms to control what data is loaded from the database:

1. **View / Input** (`.dto` files) — compile-time DTOs, the **primary approach** for most projects
2. **Fetcher** — runtime field selection, for dynamic/GraphQL-style queries

All mechanisms generate optimal SQL with only the requested columns.

**Default choice: `.dto` files.** They generate View (output) and Input (write) classes with type safety, `toEntity()` methods, and automatic fetcher definitions. Use raw Fetcher API only when fields must vary at runtime.

---

## View — Output DTOs (`.dto` files)

`View<E>` is a compile-time projection of an entity. Defined in `.dto` files, generates Java/Kotlin classes automatically.

### Defining Views in .dto files

```
// src/main/dto/Article.dto
export com.example.entity.Article
    -> package com.example.entity.dto

ArticleListView {
    id
    title
    status
    createdAt
    category {
        id
        name
    }
}

ArticleDetailView {
    #allScalars
    category {
        id
        name
    }
    comments {
        id
        content
        createdAt
    }
}
```

### Using Views in queries

```kotlin
// Kotlin
sql.createQuery(Article::class) {
    select(table.fetch(ArticleListView::class))
}.execute()
```

```java
// Java
sql.createQuery(t)
    .select(t.fetch(ArticleListView.class))
    .execute();
```

### Generic View fetching

```kotlin
fun <V : View<Article>> findById(id: UUID, viewType: KClass<V>): V? =
    sql.createQuery(Article::class) {
        where(table.id eq id)
        select(table.fetch(viewType))
    }.fetchOneOrNull()
```

```java
public <V extends View<Article>> V findById(UUID id, Class<V> viewType) {
    var t = ARTICLE_TABLE;
    return sql.createQuery(t)
        .where(t.id().eq(id))
        .select(t.fetch(viewType))
        .fetchFirstOrNull();
}
```

### viewer() — View-based queries on KRepository/JRepository

```kotlin
// Kotlin
val article: ArticleDetailView? = repository.viewer(ArticleDetailView::class).findNullable(id)
val page: Page<ArticleListView> = repository.viewer(ArticleListView::class).findAll(page, size)
```

```java
// Java
ArticleDetailView article = repository.viewer(ArticleDetailView.class).findNullable(id);
Page<ArticleListView> page = repository.viewer(ArticleListView.class).findAll(page, size);
```

---

## Input — Write DTOs (`.dto` files)

`Input<E>` is a compile-time DTO for write operations. Generates `toEntity()` method automatically — **never build entities manually from input data**.

**Generate only the DTOs that are needed RIGHT NOW.** Don't create all possible combinations upfront:
- One View per use case (e.g., `ListView` for lists, `DetailView` for detail)
- One `CreateInput` and one `UpdateInput` if CRUD is needed
- Don't create a generic "Input" with `#allScalars` — be specific about which fields are included

Each `.dto` file exports **ONE entity only**. Never add export declarations for other entities in the same file.

### Defining Inputs in .dto files

```
input ArticleCreateInput {
    title
    content
    status
    id(category) as categoryId       // @ManyToOne — generates UUID
    id(tags) as tagIds               // @ManyToMany — generates List<UUID>
}

input ArticleUpdateInput {
    id
    title
    content
    status
    id(category) as categoryId
    id(tags) as tagIds
    version
}
```

**`id()` works for ALL association types** — @ManyToOne (generates single ID), @OneToMany and @ManyToMany (generates `List<ID>`). There is no `ids()` function — always use `id()`.

### Using Input.toEntity()

```kotlin
// Kotlin
fun create(input: ArticleCreateInput): Article =
    repository.save(input.toEntity(), SaveMode.INSERT_ONLY)

fun update(input: ArticleUpdateInput): Article =
    repository.save(input.toEntity(), SaveMode.UPDATE_ONLY)
```

```java
// Java
public Article create(ArticleCreateInput input) {
    return repository.save(input.toEntity(), SaveMode.INSERT_ONLY);
}

public Article update(ArticleUpdateInput input) {
    return repository.save(input.toEntity(), SaveMode.UPDATE_ONLY);
}
```

**KRepository/JRepository also accepts Input directly:**

```kotlin
repository.save(input)  // calls input.toEntity() internally
```

### Merging multiple inputs

```kotlin
val merged = Input.toMergedEntity(baseInput, overrideInput)
```

---

## .dto File Syntax Quick Reference

```
#allScalars              // all non-association properties
-content                 // exclude field
title as articleTitle    // rename/alias
category? { id; name }  // force nullable
id(category) as categoryId  // @ManyToOne — single ID
id(tags) as tagIds       // @ManyToMany — List<ID> (NOT ids(), always id())
flat(author) {           // flatten nested object
    name as authorName
}
children* { #allScalars } // recursive (tree structures)
```

**View vs Input vs Specification:**

| Type | Keyword | Implements | Purpose |
|---|---|---|---|
| View | (none) | `View<E>` | Read-only output projection |
| Input | `input` | `Input<E>` | Write input (API request body) |
| Specification | `specification` | QBE-like query object | Dynamic WHERE builder |

For full `.dto` syntax reference, use `/jimmer-build-query`.

---

## When to Use What

| Mechanism | Use Case |
|---|---|
| **View (.dto)** | REST responses, search results, list/detail views — **default choice** |
| **Input (.dto)** | API request bodies, form submissions — **default choice for writes** |
| **Fetcher** | Dynamic queries where fields vary at runtime (GraphQL-style APIs, user-configurable projections) |

### View vs Fetcher trade-offs

- **View:** type-safe at compile time, generates DTO class, automatic `toEntity()`, easier to use in REST
- **Fetcher:** flexible at runtime, no extra class needed, good for GraphQL-style APIs
- **Performance:** identical — both generate optimal SQL

---

## Fetcher API

Use Fetcher when you need runtime-dynamic field selection. For fixed projections, prefer View DTOs.

### Basic usage

```kotlin
// Kotlin — use table.fetchBy { } DSL
sql.createQuery(Article::class) {
    select(table.fetchBy {
        allScalarFields()
        author { name(); email() }
    })
}

// For standalone fetcher (outside queries):
val fetcher = newFetcher(Article::class).by {
    allScalarFields()
    author { name(); email() }
}
val article = sql.findById(fetcher, articleId)
```

```java
// Java — use ARTICLE_FETCHER from generated Fetchers interface
ArticleFetcher fetcher = ARTICLE_FETCHER
    .allScalarFields()
    .author(AUTHOR_FETCHER.name().email());

Article article = sql.findById(fetcher, articleId);
```

**Java: always use `ARTICLE_FETCHER` from the generated `Fetchers` interface**, not `ArticleFetcher.$`.

### Field selection methods

| Method | What it includes |
|---|---|
| `allScalarFields()` | All non-association, non-formula properties |
| `allReferenceFields()` | All foreign-key associations (id only) |
| `allTableFields()` | `allScalarFields()` + `allReferenceFields()` |
| `propertyName()` | Include specific property |
| `propertyName(childFetcher)` | Include association with nested fetcher |

### Removing fields

```kotlin
newFetcher(Article::class).by {
    allScalarFields()
    -content()  // exclude content field
}
```

```java
ARTICLE_FETCHER
    .allScalarFields()
    .content(false);  // exclude
```

### Recursive fetchers (tree structures)

```kotlin
newFetcher(Category::class).by {
    allScalarFields()
    children({
        recursive()  // load all levels
    })
}
```

---

## Anti-Patterns

### Don't define static fetcher constants for fixed projections

```java
// WRONG — manual fetcher constants for fixed shapes
private static final RecipeFetcher LIST_FETCHER = RECIPE_FETCHER
    .allScalarFields()
    .category(CATEGORY_FETCHER.name());

private static final RecipeFetcher DETAIL_FETCHER = RECIPE_FETCHER
    .allScalarFields()
    .category(CATEGORY_FETCHER.allScalarFields())
    .ingredients(INGREDIENT_FETCHER.allScalarFields());

// CORRECT — use .dto file Views
// RecipeListView and RecipeDetailView defined in Recipe.dto
// Use: table.fetch(RecipeListView.class) or repository.viewer(RecipeListView.class)
```

### Don't create manual record/class DTOs when .dto files can generate them

```java
// WRONG — manual Java record with manual mapping
public record RecipeInput(String title, String content, UUID categoryId) {
    public Recipe toEntity() {
        return Immutables.createRecipe(draft -> {
            draft.setTitle(title);
            draft.setContent(content);
            draft.applyCategory(cat -> cat.setId(categoryId));
        });
    }
}

// CORRECT — .dto file generates Input with toEntity() automatically
// input RecipeCreateInput { title; content; id(category) as categoryId }
// Generated class has toEntity() built-in
```

### Don't return raw entities from REST endpoints

```kotlin
// Wrong — exposes all fields, may have lazy-loading issues
@GetMapping
fun list(): List<Article> = repository.findAll()

// Correct — return a View with only needed fields
@GetMapping
fun list(): Page<ArticleListView> = service.getAll(page, size)
```

---

## N+1 Prevention

Jimmer solves N+1 at the framework level. Both Fetcher and View generate optimal SQL:

- **Single entity:** JOIN for associations
- **List of entities:** batch loading with IN clause

### Batch size configuration

```yaml
jimmer:
  default-batch-size: 128        # for to-one associations
  default-list-batch-size: 16    # for to-many associations
```

---

## Generated Code Structure

Jimmer's annotation processor generates:

| Generated Class | Purpose |
|---|---|
| `ArticleDraft` | Mutable builder for creating/modifying entities |
| `ArticleTable` / `ArticleTableEx` | Typed table for queries (Java) |
| `ArticleFetcher` | Fetcher with typed property methods |
| `ArticleProps` | Property references for Jimmer APIs |
| `Tables` | Interface with `ARTICLE_TABLE` constants for all entities |
| `Fetchers` | Interface with `ARTICLE_FETCHER` constants for all entities |
| `Immutables` | Static factory: `Immutables.createArticle()` for entity creation (Java) |
| `*View`, `*Input` | DTO classes from `.dto` files |

### Java: always use generated utility interfaces

```java
import static com.example.entity.Tables.*;
import static com.example.entity.Fetchers.*;

ArticleTable t = ARTICLE_TABLE;          // not ArticleTable.$
ArticleFetcher f = ARTICLE_FETCHER;      // not ArticleFetcher.$
Immutables.createArticle(draft -> {...}); // not ArticleDraft.$.produce()
```

### Entity creation

See **jimmer-entity-design.md → Entity Creation DSL** for Kotlin (`Entity { ... }`) and Java (`Immutables.createEntity()`) syntax.
