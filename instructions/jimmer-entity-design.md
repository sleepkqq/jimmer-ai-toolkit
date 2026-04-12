# Jimmer Entity Design

## Interface-Based Entities

Jimmer entities are **immutable interfaces**, not classes. The framework generates implementations via annotation processing (KSP for Kotlin, APT for Java).

```kotlin
// Kotlin
@Entity
interface Article {
    @Id
    @GeneratedValue(generatorType = UUIDIdGenerator::class)
    val id: UUID

    val title: String
    val content: String

    @ManyToOne
    @JoinColumn(name = "author_id")
    val author: Author
}
```

```java
// Java
@Entity
public interface Article {
    @Id
    @GeneratedValue(generatorType = UUIDIdGenerator.class)
    UUID id();

    String title();
    String content();

    @ManyToOne
    @JoinColumn(name = "author_id")
    Author author();
}
```

---

## Field Ordering Convention

Follow this order in every entity:

1. **@Id** — primary key, always first
2. **Primary fields** — name, title, core business data
3. **Secondary fields** — status, priority, metadata
4. **Audit/version fields** — createdAt, updatedAt, version (if not inherited)
5. **All associations last** — @ManyToOne, @OneToMany, @OneToOne, @ManyToMany

---

## @Id Strategy

### Built-in ID Generators

Jimmer provides `UUIDIdGenerator` out of the box — **never create your own**:

```kotlin
import org.babyfish.jimmer.sql.meta.UUIDIdGenerator
```

```java
import org.babyfish.jimmer.sql.meta.UUIDIdGenerator;
```

### Auto-generated UUID

```kotlin
@Id
@GeneratedValue(generatorType = UUIDIdGenerator::class)
val id: UUID
```

Use when: entity lifecycle is managed entirely by your application.

### Auto-generated Long (sequence)

```kotlin
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
val id: Long
```

Use when: you need sequential IDs or database handles generation.

### Externally provided

```kotlin
@Id
val id: UUID  // no @GeneratedValue
```

Use when: ID comes from an external system (auth provider, external API, imported data).

---

## @MappedSuperclass — Base Entity Patterns

If the project already has base entity interfaces — use them as-is. The examples below are a common pattern for new projects.

### Auditable (creation timestamp only)

```kotlin
@MappedSuperclass
interface Auditable {
    val createdAt: Instant
}
```

### Model (full audit + optimistic locking)

```kotlin
@MappedSuperclass
interface Model : Auditable {
    val updatedAt: Instant

    @Version
    val version: Int
}
```

**When to use Model:** entities that are updated after creation (user profiles, orders, settings).

**When to use plain @Entity:** reference/lookup data that rarely changes (countries, currencies, enum-like tables), or child entities where parent manages lifecycle.

---

## @Table Annotation

Only needed when the table name differs from the entity name in snake_case:

```kotlin
// NOT needed: Article -> article (matches)
@Entity
interface Article { ... }

// Needed: Article -> articles (doesn't match)
@Entity
@Table(name = "articles")
interface Article { ... }
```

---

## Associations

### @ManyToOne

```kotlin
@ManyToOne
@JoinColumn(name = "category_id")
val category: Category
```

**Rule:** `@JoinColumn` goes directly under the association annotation, above the field.

### Nullable FK (optional association)

```kotlin
@ManyToOne
@JoinColumn(name = "category_id")
val category: Category?  // Kotlin nullable = DB column allows NULL
```

### @OneToMany

```kotlin
@OneToMany(mappedBy = "article")
val comments: List<Comment>
```

`mappedBy` points to the FK property name on the child entity.

### @OneToMany with cascade delete

```kotlin
@OneToMany(mappedBy = "article")
@OnDissociate(DissociateAction.DELETE)
val comments: List<Comment>
```

Required when using `AssociatedSaveMode.REPLACE` — tells Jimmer to DELETE children that are no longer in the collection.

### @OneToOne

```kotlin
// FK owner side
@OneToOne
@JoinColumn(name = "profile_id")
val profile: Profile

// Non-owner side (inverse)
@OneToOne(mappedBy = "article")
val metadata: ArticleMetadata?
```

### @ManyToMany

```kotlin
@ManyToMany
@JoinTable(
    name = "article_tag",
    joinColumnName = "article_id",
    inverseJoinColumnName = "tag_id"
)
val tags: List<Tag>
```

---

## @Key — Natural Key

Marks properties as the business identity of an entity. Used by Jimmer to find existing records during upsert operations.

```kotlin
@Entity
@KeyUniqueConstraint
interface Tag {
    @Id
    @GeneratedValue(generatorType = UUIDIdGenerator::class)
    val id: UUID

    @Key
    val name: String
}
```

### When to add @Key

- Entity has a natural business identifier (name, code, email)
- You need UPSERT semantics (save without knowing the @Id)
- Seed/import jobs that sync external data

### When NOT to add @Key

- On entities used as `@OneToOne` by multiple parents — Jimmer will reuse rows with matching key values, causing FK conflicts
- On pure child entities where the parent controls lifecycle (use `VIOLENTLY_REPLACE` instead)

### @KeyUniqueConstraint

Entity-level annotation. Tells Jimmer that a unique constraint exists in the database covering all `@Key` fields. Enables atomic `INSERT ON CONFLICT DO UPDATE` instead of SELECT → INSERT/UPDATE.

```kotlin
@Entity
@KeyUniqueConstraint
interface Category {
    @Id val id: UUID
    @Key val slug: String
    val name: String
}
```

Without `@KeyUniqueConstraint`: Jimmer does SELECT first (race condition possible).
With `@KeyUniqueConstraint`: Jimmer uses database-level upsert (atomic).

### Composite Key

```kotlin
@Entity
@KeyUniqueConstraint
interface DailyMetric {
    @Id val id: UUID

    @Key
    val day: LocalDate

    @Key
    @ManyToOne
    @JoinColumn(name = "product_id")
    val product: Product
}
```

### Key Groups

Multiple independent natural keys on the same entity:

```kotlin
@Entity
interface Account {
    @Id val id: UUID

    @Key(group = "email")
    val email: String

    @Key(group = "username")
    val username: String
}
```

---

## @OnDissociate — Child Lifecycle

Controls what happens to child records when they are dissociated from a parent.

**CRITICAL: `@OnDissociate` goes on the `@ManyToOne` / `@OneToOne` side (FK owner), NOT on `@OneToMany`.** Jimmer will throw an error if placed on `@OneToMany`.

| Action | Behavior |
|---|---|
| `DELETE` | Delete the child record (physically or logically) |
| `SET_NULL` | Set the FK column to NULL (child becomes orphan) |
| `CHECK` | Throw exception if child exists (prevent dissociation) |
| `LAX` | Do nothing (let DB constraints handle it) |

**Common pattern:** use `DELETE` for owned children, `SET_NULL` for shared references.

```kotlin
// Child entity — @OnDissociate on the FK side (@ManyToOne)
@Entity
interface Comment {
    @Id val id: UUID

    @ManyToOne
    @OnDissociate(DissociateAction.DELETE)  // delete comment when article is deleted
    @JoinColumn(name = "article_id")
    val article: Article
}

// Parent entity — NO @OnDissociate on @OneToMany
@Entity
interface Article {
    @Id val id: UUID

    @OneToMany(mappedBy = "article")
    val comments: List<Comment>  // @OnDissociate is on Comment.article, not here
}
```

---

## Enum Mapping

Jimmer maps Java/Kotlin enums to database columns. Default mapping is by `name()` (string).

```kotlin
enum class OrderStatus {
    PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED
}

@Entity
interface Order {
    @Id val id: UUID
    val status: OrderStatus  // stored as VARCHAR in DB
}
```

For ordinal mapping, use `@EnumType(EnumType.Strategy.ORDINAL)` on the enum class.

---

## JSON Columns (@Serialized)

For complex objects stored as JSONB in PostgreSQL:

```kotlin
@Entity
interface Product {
    @Id val id: UUID
    val name: String

    @Serialized
    val metadata: Map<String, Any>

    @Serialized
    val tags: List<String>
}
```

The database column type should be `jsonb` (PostgreSQL) or `json` (MySQL).

---

## DraftInterceptor — Auto-Setting Fields

Intercepts entity saves to automatically set fields like timestamps. If the project already handles audit fields differently (e.g., DB triggers, a single interceptor), follow that approach.

For new projects using the Auditable/Model pattern above: each @MappedSuperclass with auto-managed fields needs its own interceptor. Entities extending only `Auditable` (not `Model`) won't be handled by `ModelDraftInterceptor`.

```kotlin
// Handles ALL entities extending Auditable (including Model entities)
@Component
class AuditableDraftInterceptor : DraftInterceptor<Auditable, AuditableDraft> {
    override fun beforeSave(draft: AuditableDraft, original: Auditable?) {
        if (original == null) { // INSERT
            if (!ImmutableObjects.isLoaded(draft, AuditableProps.CREATED_AT)) {
                draft.createdAt = Instant.now()
            }
        }
    }
}
```

```kotlin
// Handles entities extending Model (adds updatedAt + version on top of Auditable)
@Component
class ModelDraftInterceptor : DraftInterceptor<Model, ModelDraft> {
    override fun beforeSave(draft: ModelDraft, original: Model?) {
        draft.updatedAt = Instant.now()
        if (original == null) { // INSERT
            if (!ImmutableObjects.isLoaded(draft, ModelProps.VERSION)) {
                draft.version = 0
            }
        }
    }
}
```

```java
// Java — AuditableDraftInterceptor
@Component
public class AuditableDraftInterceptor implements DraftInterceptor<Auditable, AuditableDraft> {
    @Override
    public void beforeSave(@NotNull AuditableDraft draft, @Nullable Auditable original) {
        if (original == null) {
            if (!ImmutableObjects.isLoaded(draft, AuditableProps.CREATED_AT)) {
                draft.setCreatedAt(Instant.now());
            }
        }
    }
}
```

```java
// Java — ModelDraftInterceptor
@Component
public class ModelDraftInterceptor implements DraftInterceptor<Model, ModelDraft> {
    @Override
    public void beforeSave(@NotNull ModelDraft draft, @Nullable Model original) {
        draft.setUpdatedAt(Instant.now());
        if (original == null) {
            if (!ImmutableObjects.isLoaded(draft, ModelProps.VERSION)) {
                draft.setVersion(0);
            }
        }
    }
}
```

**Key: `AuditableDraftInterceptor` sets `createdAt`, `ModelDraftInterceptor` sets `updatedAt` + `version`. Both are needed.** Model entities receive both interceptors (Jimmer walks the type hierarchy).

**Important:** DraftInterceptor causes an additional SELECT per save operation (to get `original`). For bulk inserts where you don't need the interceptor, consider setting fields explicitly.

**Placement:** DraftInterceptor belongs in the **model module** (next to entities), not in the service module. It is part of the data model's behavior, not business logic. The interceptor is registered as a Spring `@Component` / Quarkus `@ApplicationScoped` bean and auto-discovered by Jimmer.

---

## Entity Creation DSL

### Kotlin

**Always use `Entity { ... }` DSL:**

```kotlin
val article = Article {
    title = "Hello World"
    content = "Content here"
    status = ArticleStatus.DRAFT
    category = Category { id = categoryId }  // FK by id-only reference
}
```

**NEVER use** `new(Entity::class).by { ... }` or `ArticleDraft.$.produce { ... }` — they are verbose and unnecessary in Kotlin.

### Java

**Always use `Immutables.createEntity()` — generated static factory:**

```java
Article article = Immutables.createArticle(draft -> {
    draft.setTitle("Hello World");
    draft.setContent("Content here");
    draft.setStatus(ArticleStatus.DRAFT);
    draft.applyCategory(cat -> cat.setId(categoryId));  // FK by id-only reference
});
```

**NEVER use** `ArticleDraft.$.produce(draft -> { ... })` — verbose, unnecessary.

`Immutables` is a generated utility class with `create{EntityName}()` static methods for every entity.

---

## Decision Tree

### New entity checklist

1. Does it need update tracking? → extend `Model` (updatedAt + @Version)
2. Does it only need creation time? → extend `Auditable`
3. Is it reference/lookup data? → plain `@Entity`, no base class
4. Does it have a natural business key? → add `@Key` + `@KeyUniqueConstraint`
5. Does it own children that should be deleted with it? → `@OnDissociate(DELETE)` on @OneToMany
6. Is it a child of a @OneToOne? → do NOT put `@Key` on it
7. Does it store complex data? → use `@Serialized` for JSON columns
8. Is the ID from an external source? → omit `@GeneratedValue`
