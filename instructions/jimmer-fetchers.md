# Jimmer Fetchers & Generated Code

## View vs Fetcher

Two mechanisms to control loaded data:

1. **View** (`.dto` files) — compile-time projection, **primary approach**
2. **Fetcher** — runtime field selection, for dynamic/GraphQL-style queries

Use Fetcher only when the set of fields must vary at runtime. For everything else — View DTOs.

---

## Input DTOs

`Input<E>` generates `toEntity()` automatically — never build entities manually from inputs.

Input DTOs are created via constructor or JSON deserialization, not via `Immutables.create*()` (that's for entities only).

```java
// service layer
Article article = input.toEntity();
repository.save(article);
```

---

## Fetcher API

```java
// Use ARTICLE_FETCHER from generated Fetchers interface — never ArticleFetcher.$
ARTICLE_FETCHER
    .allScalarFields()
    .author(AUTHOR_FETCHER.name().email());
```

| Method | Includes |
|---|---|
| `allScalarFields()` | All non-association properties |
| `allReferenceFields()` | All FK associations (id only) |
| `allTableFields()` | Scalars + references |

---

## N+1 Prevention

Jimmer solves N+1 automatically via batch loading with IN clause.

```yaml
jimmer:
  default-batch-size: 128       # to-one associations
  default-list-batch-size: 16   # to-many associations
```

---

## Generated Code

| Generated class | Purpose |
|---|---|
| `ArticleDraft` | Mutable builder for entities |
| `ArticleTable` / `ArticleTableEx` | Typed query tables |
| `Tables` | Constants: `ARTICLE_TABLE`, `ARTICLE_TABLE_EX` |
| `Fetchers` | Constants: `ARTICLE_FETCHER` |
| `Immutables` | Entity factory — entities only, not Input/View |
| `*View`, `*Input` | DTO classes generated from `.dto` files |

Java: always use `ARTICLE_TABLE` from `Tables`, `ARTICLE_FETCHER` from `Fetchers` — never `$` references.
