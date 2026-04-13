# Jimmer Fetchers, Views, and DTOs

## Overview

Two mechanisms to control loaded data:

1. **View / Input** (`.dto` files) — compile-time DTOs, **primary approach**
2. **Fetcher** — runtime field selection, for dynamic/GraphQL-style queries

**Default choice: `.dto` files.** Use Fetcher only when fields must vary at runtime.

---

## View — Output DTOs

`View<E>` is a compile-time projection. Defined in `.dto` files, generates classes automatically.

```
export com.example.entity.Article
    -> package com.example.entity.dto

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
```

Using in queries: `t.fetch(ArticleListView.class)`.

Using with repository: `repository.viewer(ArticleDetailView.class).findNullable(id)`.

---

## Input — Write DTOs

`Input<E>` generates `toEntity()` automatically — **never build entities manually**.

**Generate only needed DTOs.** One View per use case, one CreateInput + UpdateInput if CRUD needed. One export per `.dto` file.

```
input ArticleCreateInput {
    title
    content
    id(category) as categoryId       // @ManyToOne — single ID
    id(tags) as tagIds               // @ManyToMany — List<ID>
}

input ArticleUpdateInput {
    id
    title
    content
    id(category) as categoryId
    id(tags) as tagIds
    version                          // include for @Version entities
}
```

**`id()` works for ALL association types.** There is no `ids()` — always use `id()`.

**Input DTOs are created via constructor or JSON deserialization**, not via `Immutables.create*()` (that's for entities only).

---

## .dto Syntax Reference

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

| Type | Keyword | Purpose |
|---|---|---|
| View | (none) | Read-only output projection |
| Input | `input` | Write input (request body) |
| Specification | `specification` | Dynamic WHERE builder |

---

## Fetcher API

Use when fields must vary at runtime. For fixed projections, prefer View DTOs.

```java
// Use ARTICLE_FETCHER from generated Fetchers interface (never ArticleFetcher.$)
ARTICLE_FETCHER.allScalarFields().author(AUTHOR_FETCHER.name().email());
```

| Method | What it includes |
|---|---|
| `allScalarFields()` | All non-association properties |
| `allReferenceFields()` | All FK associations (id only) |
| `allTableFields()` | Scalars + references |

**Don't define static fetcher constants for fixed projections** — use View DTOs instead.

**Don't create manual record/class DTOs** — use `.dto` files.

---

## N+1 Prevention

Jimmer solves N+1 automatically — batch loading with IN clause.

```yaml
jimmer:
  default-batch-size: 128        # to-one associations
  default-list-batch-size: 16    # to-many associations
```

---

## Generated Code

| Generated | Purpose |
|---|---|
| `ArticleDraft` | Mutable builder for entities |
| `ArticleTable` / `ArticleTableEx` | Typed query tables (Java) |
| `Tables` / `Fetchers` | Constants: `ARTICLE_TABLE`, `ARTICLE_FETCHER` |
| `Immutables` | Entity factory: `Immutables.createArticle()` (**entities only**, not Input/View) |
| `*View`, `*Input` | DTO classes from `.dto` files |

**Java:** always use `ARTICLE_TABLE` from `Tables`, `ARTICLE_FETCHER` from `Fetchers` — never `$` references.
