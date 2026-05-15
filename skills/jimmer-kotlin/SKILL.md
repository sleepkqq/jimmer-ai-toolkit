---
name: jimmer-kotlin
description: |
  Kotlin-specific Jimmer entity, KRepository, query DSL, saveCommand, DraftInterceptor, config, and KSP patterns.
triggers:
  - "Kotlin Jimmer"
  - "KRepository"
  - "KSP"
  - "DraftInterceptor"
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

- `table` supports associations; no `TableEx` needed.
- Null-safe operators include ``eq?``, ``ne?``, ``gt?``, ``ge?``, ``lt?``, ``le?``, ``like?``.
- Use `KClass<V>` instead of `Class<V>`.
- Save view result uses `.modifiedView`.
- Config must set `jimmer.language: kotlin` when required by project.
- KSP dependency must be present.

## DraftInterceptor

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
