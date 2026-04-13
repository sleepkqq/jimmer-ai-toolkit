# Jimmer Kotlin Reference

This file supplements the main toolkit for Kotlin projects. Import it when working with Kotlin + Jimmer.

## Key Differences from Java

### Entity Definition

```kotlin
@Entity
interface Article {
    @Id
    @GeneratedValue(generatorType = UUIDIdGenerator::class)
    val id: UUID
    val title: String
    @ManyToOne
    @JoinColumn(name = "category_id")
    val category: Category
}
```

### Entity Creation DSL

```kotlin
// Always use Entity { } DSL (never new(Entity::class).by { })
val article = Article {
    title = "Hello World"
    category = Category { id = categoryId }  // FK by id-only reference
}
```

### KRepository

```kotlin
interface ArticleRepository : KRepository<Article, UUID> {
    fun findByStatus(status: ArticleStatus): List<Article>

    fun <V : View<Article>> search(
        titleQuery: String?, status: ArticleStatus?,
        page: Int, size: Int, viewType: KClass<V>
    ): Page<V> =
        sql.createQuery(Article::class) {
            where(table.title `like?` titleQuery)
            where(table.status `eq?` status)
            orderBy(table.createdAt.desc())
            select(table.fetch(viewType))
        }.fetchPage(page, size)
}
```

### Query DSL — Kotlin-specific

- `table` supports ALL associations (no TableEx needed)
- Backtick operators for null-safe predicates: `eq?`, `ne?`, `gt?`, `ge?`, `lt?`, `le?`, `like?`
- `KClass` instead of `Class`: `viewType: KClass<V>`

### Save Pattern

```kotlin
repository.saveCommand(input)
    .setMode(SaveMode.INSERT_ONLY)
    .execute(RecipeDetailView::class)
    .modifiedView
```

### DraftInterceptor

```kotlin
@Component
class ModelDraftInterceptor : DraftInterceptor<Model, ModelDraft> {
    override fun beforeSave(draft: ModelDraft, original: Model?) {
        draft.updatedAt = Instant.now()
        if (original == null && !ImmutableObjects.isLoaded(draft, ModelProps.VERSION)) {
            draft.version = 0
        }
    }
}
```

### Configuration

```yaml
jimmer:
  language: kotlin  # REQUIRED for Kotlin projects
```

### Build — Gradle KSP

```kotlin
plugins {
    id("com.google.devtools.ksp")
}
dependencies {
    ksp(libs.jimmer.ksp)
}
```
