---
name: jimmer-kotlin
description: |
  Kotlin-specific Jimmer entity, KRepository, query DSL, saveCommand DSL, DraftInterceptor vs DraftPreProcessor, config, and KSP patterns.
triggers:
  - "Kotlin Jimmer"
  - "KRepository"
  - "KSP"
  - "DraftInterceptor"
  - "DraftPreProcessor"
  - "jimmer language kotlin"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Kotlin

Use when target project uses Kotlin with Jimmer.

## Entity

```kotlin
@Entity
interface DomainObject {
    @Id
    @GeneratedValue(generatorType = UUIDIdGenerator::class)
    val id: UUID
    val name: String

    @ManyToOne
    @JoinColumn(name = "related_object_id")
    val relatedObject: RelatedObject
}
```

Nullability via Kotlin `T?`, not annotations.

## Creation DSL

Use generated DSL:

```kotlin
val domainObject = DomainObject {
    name = "value"
    relatedObject = RelatedObject { id = relatedObjectId }
}
```

Do not use old `new(Entity::class).by { }` style.

## KRepository Query

```kotlin
interface DomainObjectRepository : KRepository<DomainObject, UUID> {
    fun <V : View<DomainObject>> search(
        nameQuery: String?,
        page: Int,
        size: Int,
        viewType: KClass<V>,
    ): Page<V> =
        sql.createQuery(DomainObject::class) {
            where(table.name `like?` nameQuery)
            orderBy(table.createdAt.desc())
            select(table.fetch(viewType))
        }.fetchPage(page, size)
}
```

## Kotlin Rules

- `table` supports collection joins; no `TableEx` needed.
- Null-safe operators: ``eq?``, ``ne?``, ``gt?``, ``ge?``, ``lt?``, ``le?``, ``like?``, ``valueIn?`` — null (and empty string for like) skips the predicate.
- Use `KClass<V>` instead of `Class<V>`.
- Save command options via DSL lambda: `sql.save(entity) { setMode(...); setAssociatedModeAll(...) }`; save view result uses `.modifiedView`.
- Config must set `jimmer.language: kotlin` (or `quarkus.jimmer.language: kotlin`).
- KSP dependency must be present; DTO/draft generation runs through KSP.

## DraftInterceptor vs DraftPreProcessor

`DraftInterceptor` forces an existence-check SELECT before save (`QueryReason.INTERCEPTOR`) and disables SQL-level upsert — use it only when logic needs `original`. For unconditional defaults prefer `DraftPreProcessor` (no query, keeps upsert fast path).

```kotlin
@ApplicationScoped
class ModelDraftInterceptor : DraftInterceptor<Model, ModelDraft> {
    override fun beforeSave(draft: ModelDraft, original: Model?) {
        draft.updatedAt = Instant.now()
        if (original == null && !isLoaded(draft, Model::version)) {
            draft.version = 0
        }
    }

    // batch variant to avoid N+1 in interceptor logic:
    // override fun beforeSaveAll(items: Collection<DraftInterceptor.Item<Model, ModelDraft>>)

    // props of `original` to load beyond id/key:
    // override fun dependencies(): Collection<TypedProp<Model, *>>
}
```

```kotlin
@ApplicationScoped
class ModelPreProcessor : DraftPreProcessor<ModelDraft> {
    override fun beforeSave(draft: ModelDraft) {
        if (!isLoaded(draft, Model::createdAt)) draft.createdAt = Instant.now()
    }
}
```
