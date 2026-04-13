# Jimmer Repository Patterns

## Adaptation Rule

**This toolkit does not impose patterns. It adapts to the project.**

Before generating code:
1. **Scan existing source files** — match formatting (indentation, brace style, blank lines, naming), architecture patterns, and code style. Check `.editorconfig`, `checkstyle.xml`, `detekt.yml` if present.
2. **Follow existing project conventions** — if the project uses raw `KSqlClient`/`JSqlClient` repositories instead of `KRepository`/`JRepository`, continue in that style. If the project uses a specific package structure, follow it.
3. **Suggest better alternatives when asked** — if you know a more efficient Jimmer pattern (e.g., KRepository over raw KSqlClient), mention it only when the user asks for improvements, code review, or best practices. Don't silently rewrite working code into a different style.

---

## Layer Architecture

```
Controller/Resource  →  Service  →  Repository  →  KSqlClient/JSqlClient
     (REST API)      (business)   (data access)      (Jimmer ORM)
```

- **Controller** (Spring Boot `@RestController`) / **Resource** (Quarkus JAX-RS `@Path`) — REST endpoints, no business logic, delegates to Service
- **Service** — business logic, transaction boundaries, validation
- **Repository** — data access only, uses KSqlClient/JSqlClient directly

**Naming convention:**
- Spring Boot → `ArticleController` (`@RestController`, `@GetMapping`, `@PostMapping`)
- Quarkus → `ArticleResource` (`@Path`, `@GET`, `@POST`)

Don't mix — use Controller for Spring Boot, Resource for Quarkus.

---

## KRepository / JRepository

**For new projects, prefer KRepository/JRepository.** It provides built-in CRUD, abstract method queries, and access to `sql` client for complex queries inside default methods — all in one interface.

**Only define custom methods that are actually needed.** JRepository/KRepository already provides findNullable, findById, save, deleteById, findAll, viewer(), etc. Don't generate all possible `findBy*` methods upfront — add them when business logic requires them.

**Import depends on framework:**

| Framework | KRepository import | JRepository import |
|---|---|---|
| Spring Boot | `org.babyfish.jimmer.spring.repository.KRepository` | `org.babyfish.jimmer.spring.repository.JRepository` |
| Quarkus | `io.quarkiverse.jimmer.runtime.repository.KRepository` | `io.quarkiverse.jimmer.runtime.repository.JRepository` |

KSqlClient/JSqlClient imports are the same for both: `org.babyfish.jimmer.sql.kt.KSqlClient` / `org.babyfish.jimmer.sql.JSqlClient`.

**Key API notes for KRepository/JRepository:**
- `save(entity)` → returns entity directly (not SimpleSaveResult — `.modifiedEntity` is called internally)
- `save(entity, mode)` → same, returns entity with explicit SaveMode
- `save(input)` → accepts Input DTO, returns entity
- `findNullable(id)` → returns `E?` (nullable), prefer over `findById(id)` which returns `Optional<E>`
- `viewer(viewType).findAll(page, size)` → returns `Page<V>` for View-based queries
- `viewer(viewType).findNullable(id)` → returns `V?` for single View lookup
- `sql` property → access to KSqlClient for custom queries in default methods

```kotlin
// Kotlin — KRepository with built-in + abstract + custom queries in one interface
interface ArticleRepository : KRepository<Article, UUID> {

    // Abstract method query — Jimmer generates SQL from method name
    fun findByStatus(status: ArticleStatus): List<Article>

    // Custom complex query — use sql client via default method
    // KRepository exposes `sql` (KSqlClient) for use inside default methods
    fun <V : View<Article>> search(
        titleQuery: String?,
        status: ArticleStatus?,
        categoryId: UUID?,
        page: Int,
        size: Int,
        viewType: KClass<V>
    ): Page<V> =
        sql.createQuery(Article::class) {
            where(table.title `like?` titleQuery)
            where(table.status `eq?` status)
            where(table.category.id `eq?` categoryId)
            orderBy(table.createdAt.desc())
            select(table.fetch(viewType))
        }.fetchPage(page, size)
}
```

```java
// Java — JRepository with default methods for custom queries
public interface ArticleRepository extends JRepository<Article, UUID> {

    // Abstract method query
    List<Article> findByStatus(ArticleStatus status);

    // Custom complex query — JRepository exposes sql() for default methods
    // Use ARTICLE_TABLE_EX if filtering on @OneToMany/@ManyToMany (e.g., tags)
    default <V extends View<Article>> Page<V> search(
        @Nullable String titleQuery,
        @Nullable ArticleStatus status,
        @Nullable UUID categoryId,
        int page,
        int size,
        Class<V> viewType
    ) {
        ArticleTable t = ARTICLE_TABLE;
        return sql().createQuery(t)
            .where(t.title().likeIf(titleQuery, LikeMode.ANYWHERE))
            .where(t.status().eqIf(status))
            .where(t.category().id().eqIf(categoryId))
            .orderBy(t.createdAt().desc())
            .select(t.fetch(viewType))
            .fetchPage(page, size);
    }
}
```

**If the existing project uses raw KSqlClient/JSqlClient repositories** — follow that pattern, don't rewrite. See Adaptation Rule above.

---

## Key Patterns

### Creating entities from Input DTO

```kotlin
// Input.toEntity() generates a Jimmer entity from the Input DTO
val entity = input.toEntity()
val saved = sql.save(entity, SaveMode.INSERT_ONLY).modifiedEntity
```

### Returning a View from save result (no extra query)

Use `repository.saveCommand().execute(ViewClass).getModifiedView()` — no extra SQL query.

`saveCommand()` accepts both entity and Input DTO directly — no need to call `.toEntity()`. JRepository/KRepository exposes `saveCommand()` from the interface, so **call it from the service layer, not as a repository default method** — SaveMode/AssociatedSaveMode configuration is business logic.

```java
// Java — in service, calling repository.saveCommand()
@Service
public class RecipeService {
    private final RecipeRepository repository;

    public RecipeDetailView create(RecipeCreateInput input) {
        return repository.saveCommand(input)
            .setMode(SaveMode.INSERT_ONLY)
            .setAssociatedMode(RecipeProps.INGREDIENTS, AssociatedSaveMode.APPEND)
            .execute(RecipeDetailView.class)
            .getModifiedView();
    }

    public RecipeDetailView update(RecipeUpdateInput input) {
        return repository.saveCommand(input)
            .setMode(SaveMode.UPDATE_ONLY)
            .setAssociatedMode(RecipeProps.INGREDIENTS, AssociatedSaveMode.REPLACE)
            .execute(RecipeDetailView.class)
            .getModifiedView();
    }
}
```

```kotlin
// Kotlin — same pattern
@Service
class RecipeService(private val repository: RecipeRepository) {
    fun create(input: RecipeCreateInput): RecipeDetailView =
        repository.saveCommand(input)
            .setMode(SaveMode.INSERT_ONLY)
            .execute(RecipeDetailView::class)
            .modifiedView

    fun update(input: RecipeUpdateInput): RecipeDetailView =
        repository.saveCommand(input)
            .setMode(SaveMode.UPDATE_ONLY)
            .setAssociatedMode(RecipeProps.INGREDIENTS, AssociatedSaveMode.REPLACE)
            .execute(RecipeDetailView::class)
            .modifiedView
}
```

**NEVER do save + findById to get a View.** Use `execute(ViewClass)` instead.

### Setting FK by ID only

Don't load the entire parent entity just to set a FK:

```kotlin
// Correct — id-only reference
category = Category { id = categoryId }

// Wrong — unnecessary DB query
category = categoryRepository.findById(categoryId)!!
```

### Returning different Views for list vs detail

Use generic `viewType` — the controller decides which View each endpoint returns:

```kotlin
// Controller passes the appropriate View class
fun list() = service.getAll(page, size, ArticleListView::class)     // lightweight
fun getById(id) = service.getById(id, ArticleDetailView::class)     // full detail
```

### Pagination response

Jimmer's `Page<T>` contains:
- `rows: List<T>` — current page data
- `totalRowCount: Long` — total matching rows
- `totalPageCount: Long` — total pages

### Dynamic search with optional filters

```kotlin
// Kotlin — use backtick operators with ? (predicate only applied if value is non-null)
sql.createQuery(Article::class) {
    where(table.title `like?` titleQuery)       // like adds % automatically (LikeMode.ANYWHERE)
    where(table.status `eq?` status)
    where(table.category.id `eq?` categoryId)
    select(table.fetch(ArticleListView::class))
}.fetchPage(page, size)
```

```java
// Java — use eqIf/likeIf (predicate only applied if value is non-null)
sql.createQuery(T)
    .where(T.title().likeIf(titleQuery, LikeMode.ANYWHERE))
    .where(T.status().eqIf(status))
    .where(T.category().id().eqIf(categoryId))
    .select(T.fetch(ArticleListView.class))
    .fetchPage(page, size);
```

---

## Anti-Patterns to Avoid

### Don't reimplement JRepository/KRepository built-in methods

JRepository/KRepository already provides `findNullable`, `findById`, `save`, `deleteById`, `findAll`, `viewer()`, etc. Don't write custom methods that duplicate them:

```java
// WRONG — reimplements built-in findNullable with a custom fetcher
default Recipe findNullable(UUID id) {
    RecipeTable t = RECIPE_TABLE;
    return sql().createQuery(t)
        .where(t.id().eq(id))
        .select(t.fetch(DETAIL_FETCHER))
        .fetchFirstOrNull();
}

// CORRECT — use built-in methods
repository.findNullable(id);                                    // full entity
repository.findNullable(id, fetcher);                           // with fetcher
repository.viewer(RecipeDetailView.class).findNullable(id);     // with View DTO
```

Only write custom default methods for queries that **don't exist** as built-ins (search with filters, complex joins, aggregations).

### Don't build entities manually when Input.toEntity() is available

```java
// WRONG — manual entity building from input fields
public Recipe createRecipe(RecipeInput input) {
    return Immutables.createRecipe(draft -> {
        draft.setTitle(input.title());
        draft.setContent(input.content());
        draft.setStatus(input.status());
        draft.applyCategory(cat -> cat.setId(input.categoryId()));
    });
}

// CORRECT — Input DTO generates toEntity() automatically
// Define in .dto file: input RecipeCreateInput { title; content; status; id(category) as categoryId }
public Recipe createRecipe(RecipeCreateInput input) {
    return repository.save(input.toEntity(), SaveMode.INSERT_ONLY);
}
```

### NEVER save then find — use save result directly

`save()` already returns the full entity. `saveCommand().execute(ViewClass)` returns a View. **Never do a second query after save.**

```java
// WRONG — saves then queries again to get a View (2 SQL operations!)
public RecipeDetailView create(RecipeCreateInput input) {
    Recipe saved = repository.save(input.toEntity(), SaveMode.INSERT_ONLY);
    return repository.viewer(RecipeDetailView.class).findNullable(saved.id());
}

// CORRECT — saveCommand accepts Input directly, execute(ViewClass) returns View
public CategoryView create(CategoryCreateInput input) {
    return categoryRepository.saveCommand(input)
        .setMode(SaveMode.INSERT_ONLY)
        .execute(CategoryView.class)
        .getModifiedView();
}

// CORRECT — with AssociatedSaveMode for complex saves
public RecipeDetailView create(RecipeCreateInput input) {
    return recipeRepository.saveCommand(input)
        .setMode(SaveMode.INSERT_ONLY)
        .execute(RecipeDetailView.class)
        .getModifiedView();
}
```

```kotlin
// WRONG — saves then queries again (2 SQL operations!)
fun create(input: RecipeCreateInput): RecipeDetailView {
    val saved = repository.save(input.toEntity(), SaveMode.INSERT_ONLY)
    return repository.viewer(RecipeDetailView::class).findNullable(saved.id)!!
}

// CORRECT — saveCommand accepts Input directly
fun create(input: CategoryCreateInput): CategoryView =
    categoryRepository.saveCommand(input)
        .setMode(SaveMode.INSERT_ONLY)
        .execute(CategoryView::class)
        .modifiedView

// CORRECT — with AssociatedSaveMode
fun create(input: RecipeCreateInput): RecipeDetailView =
    recipeRepository.saveCommand(input)
        .setMode(SaveMode.INSERT_ONLY)
        .execute(RecipeDetailView::class)
        .modifiedView
```

**This applies at ALL layers — repository, service, AND controller.** Never re-fetch what you just saved.

### NEVER use deprecated insert()/update()

See **jimmer-save-modes.md → Deprecated methods**. Use `save()` with explicit `SaveMode`.

### Don't hardcode View types in repository/service methods

```kotlin
// WRONG — hardcoded View, need new method for every View
fun findById(id: UUID): ArticleDetailView? = ...
fun findAllList(page: Int, size: Int): Page<ArticleListView> = ...

// CORRECT — generic viewType, one method serves all callers
fun <V : View<Article>> findById(id: UUID, viewType: KClass<V>): V? = ...
fun <V : View<Article>> findAll(page: Int, size: Int, viewType: KClass<V>): Page<V> = ...
```

Pass `viewType` from controller → service → repository. The controller decides which View it needs.

### Don't load full entity for partial updates

```kotlin
// Wrong — entities are immutable, can't mutate them
val article = repository.findFullEntity(id)!!
article.title = newTitle  // COMPILE ERROR — entities are immutable!

// Correct — create partial entity with only changed fields
val patch = Article {
    this.id = id
    title = newTitle
}
sql.save(patch, SaveMode.UPDATE_ONLY)
```

**Warning:** if the entity has `@Version` (optimistic locking), partial updates without providing the version field will fail with `OptimisticLockError`. For versioned entities, always include the current version:

```kotlin
val patch = Article {
    this.id = id
    this.version = currentVersion  // required for @Version entities
    title = newTitle
}
sql.save(patch, SaveMode.UPDATE_ONLY)
```

Or use an Input DTO that includes the version field.

### Don't use findById when you only need to set a FK

```kotlin
// Wrong
val category = categoryRepository.findById(categoryId)!!
val article = Article { category = category }

// Correct — id-only reference
val article = Article { category = Category { id = categoryId } }
```

### Don't return full entities from REST endpoints

```kotlin
// Wrong — exposes all fields, may have lazy-loading issues
@GetMapping
fun list(): List<Article> = repository.findAll()

// Correct — return a View with only needed fields
@GetMapping
fun list(): Page<ArticleListView> = service.getAll(page, size)
```

### Don't inject or use KSqlClient/JSqlClient in services

Services should call repository methods. JRepository/KRepository exposes `saveCommand()` and `sql()`/`sql` — use them either from the service via `repository.saveCommand()` or in repository default methods for custom queries.

```java
// WRONG — injecting JSqlClient in service
@Service
public class RecipeService {
    private final JSqlClient sql;  // should not be here

    public RecipeDetailView create(RecipeCreateInput input) {
        return sql.saveCommand(input).setMode(SaveMode.INSERT_ONLY)
            .execute(RecipeDetailView.class).getModifiedView();
    }
}

// WRONG — wrapping saveCommand in a repository default method (SaveMode is business logic)
public interface RecipeRepository extends JRepository<Recipe, UUID> {
    default RecipeDetailView create(RecipeCreateInput input) {
        return sql().saveCommand(input).setMode(SaveMode.INSERT_ONLY)
            .execute(RecipeDetailView.class).getModifiedView();
    }
}

// CORRECT — service calls repository.saveCommand() directly
@Service
public class RecipeService {
    private final RecipeRepository repository;

    public RecipeDetailView create(RecipeCreateInput input) {
        return repository.saveCommand(input)
            .setMode(SaveMode.INSERT_ONLY)
            .execute(RecipeDetailView.class)
            .getModifiedView();
    }
}
```

**Repository default methods** are for custom queries (`sql().createQuery(...)`) — not for save wrappers.

### Don't put business logic in Controller

```kotlin
// Wrong
@PostMapping
fun create(input: ArticleCreateInput): ArticleDetailView {
    if (repository.existsBySlug(input.slug)) throw ConflictException(...)
    val entity = input.toEntity()
    return sql.save(entity).modifiedEntity
}

// Correct — delegate to service
@PostMapping
fun create(input: ArticleCreateInput): ArticleDetailView =
    service.create(input)
```
