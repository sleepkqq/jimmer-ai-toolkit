# Jimmer Entity Design

## Interface-Based Entities

Jimmer entities are **immutable interfaces**, not classes. Generated via APT (Java) or KSP (Kotlin).

```java
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

1. `@Id` → 2. Primary fields → 3. Secondary fields → 4. Audit/version → 5. Associations last

---

## @Id Strategy

Use built-in `UUIDIdGenerator` — **never create custom generators**.

```java
@Id @GeneratedValue(generatorType = UUIDIdGenerator.class) UUID id();  // UUID auto
@Id @GeneratedValue(strategy = GenerationType.IDENTITY) long id();     // Long sequence
@Id UUID id();                                                         // External (no @GeneratedValue)
```

---

## @MappedSuperclass

If project already has base interfaces — use them. Common pattern:

```java
@MappedSuperclass
public interface Auditable { Instant createdAt(); }

@MappedSuperclass
public interface Model extends Auditable {
    Instant updatedAt();
    @Version int version();
}
```

**Model** → entities updated after creation. **Plain @Entity** → reference/lookup data.

---

## @Table / @Column

- `@Table` — only if table name ≠ snake_case of entity name

**NEVER add `@Column` for standard snake_case mapping.** Jimmer auto-maps camelCase → snake_case:

```java
// WRONG — @Column is redundant, default mapping already does this
@Column(name = "impact_level")
int impactLevel();

// CORRECT — no @Column needed
int impactLevel();          // → impact_level
String firstName();         // → first_name
Instant timeCreated();      // → time_created
```

Only use `@Column` for non-standard names where default mapping doesn't work: `@Column(name = "usr_nm")`

---

## Nullability

Entity properties are **non-null by default**. For nullable fields, add `@Nullable` from `org.jetbrains.annotations`:

```java
import org.jetbrains.annotations.Nullable;

@Nullable String description();    // nullable — DB column allows NULL
String title();                    // non-null by default, no annotation needed
```

Do NOT add `@NotNull` — it's the default. Only add `@Nullable` where needed.

---

## Associations

`@JoinColumn` goes directly under the association annotation.

```java
@ManyToOne                                          // nullable: @Nullable Category category()
@JoinColumn(name = "category_id")
Category category();

@OneToMany(mappedBy = "article")                    // mappedBy = FK property name on child
List<Comment> comments();

@OneToOne
@JoinColumn(name = "profile_id")
Profile profile();

@ManyToMany
@JoinTable(name = "article_tag", joinColumnName = "article_id", inverseJoinColumnName = "tag_id")
List<Tag> tags();
```

---

## @Key — Natural Key

Business identity for upsert. Requires matching DB unique constraint via `@KeyUniqueConstraint`.

```java
@Entity
@KeyUniqueConstraint
public interface Tag {
    @Id @GeneratedValue(generatorType = UUIDIdGenerator.class) UUID id();
    @Key String name();
}
```

**Composite key** — mix scalar + FK fields:

```java
@Entity
@KeyUniqueConstraint
public interface DayActivity {
    @Id @GeneratedValue(generatorType = UUIDIdGenerator.class) UUID id();

    @Key LocalDate day();

    @Key
    @ManyToOne
    @JoinColumn(name = "player_id")
    Player player();
}
```

- **Key groups:** `@Key(group = "email")` + `@Key(group = "username")` — independent natural keys
- **Don't add @Key** on `@OneToOne` children shared by multiple parents

---

## @OnDissociate — Child Lifecycle

**Goes on `@ManyToOne`/`@OneToOne` (FK owner), NOT on `@OneToMany`.**

```java
@Entity
public interface Comment {
    @Id UUID id();
    @ManyToOne
    @OnDissociate(DissociateAction.DELETE)  // DELETE or SET_NULL
    @JoinColumn(name = "article_id")
    Article article();
}
```

---

## Enum / JSON

- **Enum:** VARCHAR by default. Ordinal: `@EnumType(EnumType.Strategy.ORDINAL)`
- **JSON:** `@Serialized Map<String, Object> metadata();` → `jsonb` in PostgreSQL

---

## DraftInterceptor

Each `@MappedSuperclass` with auto-managed fields needs its own interceptor. Jimmer walks the type hierarchy, so each level fires separately.

Example for a two-level hierarchy (`Auditable` ← `Model`):

```java
@Component
public class AuditableDraftInterceptor implements DraftInterceptor<Auditable, AuditableDraft> {
    @Override
    public void beforeSave(@NotNull AuditableDraft draft, @Nullable Auditable original) {
        if (original == null && !ImmutableObjects.isLoaded(draft, AuditableProps.CREATED_AT)) {
            draft.setCreatedAt(Instant.now());
        }
    }
}

@Component
public class ModelDraftInterceptor implements DraftInterceptor<Model, ModelDraft> {
    @Override
    public void beforeSave(@NotNull ModelDraft draft, @Nullable Model original) {
        var now = Instant.now();
        if (original == null) {
            if (!ImmutableObjects.isLoaded(draft, ModelProps.CREATED_AT)) {
                draft.setCreatedAt(now);
            }
            if (!ImmutableObjects.isLoaded(draft, ModelProps.VERSION)) {
                draft.setVersion(0);
            }
        }
        draft.setUpdatedAt(now);
    }
}
```

Adapt interceptor types and field names to the project's actual `@MappedSuperclass` interfaces.

**Placement:** model module. Causes extra SELECT per save (for `original`).

---

## Entity Creation

```java
// Create new entity
Article article = Immutables.createArticle(draft -> {
    draft.setTitle("Hello World");
    draft.applyCategory(cat -> cat.setId(categoryId));  // FK by id-only
});

// Modify existing entity (preserves unset fields)
Article updated = Immutables.createArticle(existing, draft -> {
    draft.setTitle("Updated Title");
    // version, createdAt etc. preserved from existing
});
```

`Immutables.create*()` is for **entities only**. Input/View DTOs use constructor or `@RequestBody`.

---

## Checklist

1. Needs audit fields? → extend the project's `@MappedSuperclass` base entity. None exists? → plain `@Entity`
2. Natural key? → `@Key` + `@KeyUniqueConstraint`
3. Owns children? → `@OnDissociate(DELETE)` on child's FK
4. `@OneToOne` child? → don't put `@Key` on it
5. Complex data? → `@Serialized`. External ID? → omit `@GeneratedValue`
