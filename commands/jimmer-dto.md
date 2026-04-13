---
description: "Generate .dto file (Views and Inputs) for an existing Jimmer entity"
---

# DTO Generator

Generate `.dto` file for an existing entity. Scan the entity interface first to understand its fields and associations.

## Rules

- **One `.dto` file per entity.** One export declaration per file
- **Use `#allScalars` then `-field` to exclude** — don't list every field manually
- **`id()` for associations:** `id(category) as categoryId` (@ManyToOne → single ID), `id(tags) as tagIds` (@ManyToMany → List<ID>)
- **ONLY use .dto operators listed below.** Do NOT invent operators like `count()`, `avg()`, `sum()` — computed values go in `@TypedTuple` Java classes, not .dto files
- **Generate only what the user asked for.** Don't create all possible View/Input combinations

## Process

1. **Read the entity interface** — understand fields, types, associations, @Version
2. **Determine what DTOs are needed** from user request:
   - `{Entity}View` — if only one view needed
   - `{Entity}ListView` + `{Entity}DetailView` — if list and detail differ
   - `input {Entity}CreateInput` — for creation (exclude id, audit fields)
   - `input {Entity}UpdateInput` — for update (include id, version if @Version)
3. **Write the .dto file** at `src/main/dto/{package}/{EntityName}.dto`
4. **Compile the project** (`./mvnw compile` or `./gradlew build`). Fix errors before finishing

## .dto Syntax

```
export com.example.entity.Article
    -> package com.example.entity.dto

ArticleListView {
    #allScalars
    -content                            // exclude heavy fields
    -instructions
    category { id; name }               // nested association
}

ArticleDetailView {
    #allScalars
    category { id; name }
    comments { id; content; createdAt }
    tags { id; name }
}

input ArticleCreateInput {
    title
    content
    id(category) as categoryId          // @ManyToOne — single ID
    id(tags) as tagIds                  // @ManyToMany — List<ID>
}

input ArticleUpdateInput {
    id
    title
    content
    id(category) as categoryId
    id(tags) as tagIds
    version                             // required for @Version entities
}

specification ArticleSpec {
    like/i(title)
    ge(createdAt)
    eq(status)
}
```

## Property Operators (COMPLETE list — use ONLY these)

```
#allScalars              // all non-association properties
-content                 // exclude field from #allScalars
title as articleTitle    // rename/alias
category? { id; name }  // force nullable
id(category) as catId   // @ManyToOne FK — single ID
id(tags) as tagIds      // @ManyToMany — List<ID> (NOT ids(), always id())
flat(author) { name as authorName }  // flatten nested object
children* { #allScalars }            // recursive (tree)
```

| Type | Keyword | Purpose |
|---|---|---|
| View | (none) | Read-only output projection |
| Input | `input` | Write input (request body) |
| Specification | `specification` | Dynamic WHERE builder |
