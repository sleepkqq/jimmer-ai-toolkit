# Jimmer Repository Patterns

## Adaptation Rule

**Adapt to the project.** Scan existing code, match style. Suggest alternatives only when asked.

---

## Layer Architecture

- **Controller** (`@RestController`) — REST, delegates to Service
- **Service** — business logic, calls `repository.saveCommand()` / `repository.viewer()`
- **Repository** — data access. Custom queries via default methods using `sql()`

Spring Boot → `ArticleController`. Quarkus → `ArticleResource`.

---

## JRepository API

Every repository starts empty:

```java
public interface ArticleRepository extends JRepository<Article, UUID> {
}
```

`JRepository` already provides — never reimplement these:

```java
repository.findNullable(id);
repository.findNullable(id, ARTICLE_FETCHER.title().author());
repository.viewer(ArticleDetailView.class).findNullable(id);
repository.viewer(ArticleListView.class).findAll(page, size);
repository.save(entity, SaveMode.INSERT_ONLY);
repository.saveCommand(input).setMode(SaveMode.INSERT_ONLY).execute(ArticleDetailView.class).getModifiedView();
repository.deleteById(id);
```

Custom methods are added only when the user explicitly requests a specific query that the built-ins cannot handle. `findBy*` methods are never generated speculatively — if the business logic doesn't require a custom query right now, the repository stays empty.

When a custom method is needed, use a `default` method with `sql()`:

```java
public interface ArticleRepository extends JRepository<Article, UUID> {
    default <V extends View<Article>> Page<V> search(
        @Nullable String titleQuery, @Nullable UUID categoryId,
        int page, int size, Class<V> viewType
    ) {
        var t = ARTICLE_TABLE;
        return sql().createQuery(t)
            .where(t.title().likeIf(titleQuery, LikeMode.ANYWHERE))
            .where(t.category().id().eqIf(categoryId))
            .orderBy(t.createdAt().desc())
            .select(t.fetch(viewType))
            .fetchPage(page, size);
    }
}
```

---

## Save from Service

`saveCommand()` accepts entity or Input DTO. SaveMode/AssociatedSaveMode config is business logic — call from service.

```java
@Service
public class RecipeService {
    private final RecipeRepository repository;

    // Simple save — returns View
    public CategoryView create(CategoryCreateInput input) {
        return repository.saveCommand(input)
            .setMode(SaveMode.INSERT_ONLY)
            .execute(CategoryView.class)
            .getModifiedView();
    }

    // Save with associated modes per-property
    public RecipeDetailView create(RecipeCreateInput input) {
        return repository.saveCommand(input)
            .setMode(SaveMode.INSERT_ONLY)
            .setAssociatedMode(RecipeProps.INGREDIENTS, AssociatedSaveMode.APPEND)
            .setAssociatedMode(RecipeProps.TAGS, AssociatedSaveMode.APPEND)
            .execute(RecipeDetailView.class)
            .getModifiedView();
    }

    // Save with same mode for all associations
    public RecipeDetailView update(RecipeUpdateInput input) {
        return repository.saveCommand(input)
            .setMode(SaveMode.UPDATE_ONLY)
            .setAssociatedModeAll(AssociatedSaveMode.REPLACE)
            .execute(RecipeDetailView.class)
            .getModifiedView();
    }

    // Batch save
    public void importAll(List<Article> articles) {
        sql.saveEntitiesCommand(articles)
            .setMode(SaveMode.NON_IDEMPOTENT_UPSERT)
            .execute();
    }
}
```

---

## Anti-Patterns

- **Don't reimplement built-ins** — use `findNullable`, `viewer()`, `saveCommand()` directly
- **Never save then find** — `execute(ViewClass).getModifiedView()` is one operation
- **Don't hardcode View types** — use `<V extends View<E>>` + `Class<V> viewType`
- **Don't inject JSqlClient in services** — use `repository.saveCommand()` / default methods
- **Don't return raw entities from REST** — return View DTOs
- **FK by id-only** — `Immutables.createCategory(c -> c.setId(id))`, don't load full entity
