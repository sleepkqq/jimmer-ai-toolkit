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
