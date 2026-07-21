---
name: jimmer-repositories
description: |
  Jimmer repository and service-layer patterns for JRepository/KRepository boundaries, built-ins, custom query methods, and saveCommand usage.
triggers:
  - "JRepository"
  - "KRepository"
  - "saveCommand"
  - "repository.viewer"
  - "Jimmer repository"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Repositories

Use for repository/service boundaries and save/query placement.

## Architecture

- REST/resource layer delegates to service.
- Service layer owns business logic and save mode choices.
- Repository layer owns `sql()` queries and data access.
- No direct SQL client access from service unless target project explicitly uses that pattern.

## Repository Size Rule

Every repository starts empty:

```java
public interface DomainObjectRepository extends JRepository<DomainObject, UUID> {
}
```

Add custom method only when code in current task directly calls it and built-ins cannot do it.

## Reuse Ladder

For each data need, take the FIRST rung that expresses it — and stop there:

1. **Built-in** `JRepository`/`KRepository` method (`findNullable`, `viewer(...)`, `findAll`, `save*`, `deleteById`, ...).
2. **Derived query method** — a SIGNATURE with NO body; the runtime parses the name and generates the SQL (Spring Data style; supported by Spring Data Jimmer and quarkus-jimmer-extension): `findByAuthorIdAndStatus(...)`, `fun <V : View<E>> findByUserId(userId, viewType: KClass<V>): V?`, `deleteByViewerId(viewerId): Int`. If you are writing `createQuery`/`where`/`select`, you are NOT on this rung. Writing a body that a derived name could express is a defect — and check the interface first, the method may already exist.
3. **Custom DSL method** — only when the query needs predicates/subqueries/tuples a name cannot express.

The ladder cuts BOTH ways — granularity is one METHOD CALL = one QUERY:

- Never reimplement rung 1–2 as rung 3 (duplicate of an existing/derivable method).
- Never assemble ONE result from a CHAIN of rung-1/2 calls (`findById` + `findAllByX` + `existsBy...` = 3 sequential SQL). A multi-source result is ONE rung-3 query with joins/subqueries — cheaper and atomic.

## Built-ins Not To Reimplement

```java
repository.findNullable(id);
repository.findNullable(id, DOMAIN_OBJECT_FETCHER.name().relatedObject());
repository.viewer(DomainObjectDetailView.class).findNullable(id);
repository.viewer(DomainObjectListView.class).findAll(page, size);
repository.save(entity, SaveMode.INSERT_ONLY);
repository.saveCommand(input).setMode(SaveMode.INSERT_ONLY).execute(DomainObjectDetailView.class).getModifiedView();
repository.deleteById(id);
```

## Custom Query Method

```java
default <V extends View<DomainObject>> Page<V> search(
    @Nullable String nameQuery,
    @Nullable UUID relatedObjectId,
    int page,
    int size,
    Class<V> viewType
) {
    var t = DOMAIN_OBJECT_TABLE;
    return sql().createQuery(t)
        .where(t.name().likeIf(nameQuery, LikeMode.ANYWHERE))
        .where(t.relatedObject().id().eqIf(relatedObjectId))
        .orderBy(t.createdAt().desc())
        .select(t.fetch(viewType))
        .fetchPage(page, size);
}
```

## Service Save Pattern

```java
return repository.saveCommand(input)
    .setMode(SaveMode.INSERT_ONLY)
    .execute(DomainObjectDetailView.class)
    .getModifiedView();
```

Never re-query after save just to return saved data. Use modified entity/view from save result.
