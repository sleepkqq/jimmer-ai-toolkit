---
name: jimmer-advanced-mappings
description: |
  Jimmer advanced entity mappings: @Formula, @IdView, @ManyToManyView, @LogicalDeleted, @Embeddable, @Serialized, @MapsId, @Transient resolvers, @JoinSql, and enum mapping.
triggers:
  - "@Formula"
  - "@IdView"
  - "@ManyToManyView"
  - "@LogicalDeleted"
  - "@Embeddable"
  - "@Serialized"
  - "@MapsId"
  - "TransientResolver"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Advanced Mappings

Use for computed props, id views, logical deletion, embeddables, JSON columns, and derived associations. Base entity design lives in `jimmer-entity`.

## @Formula — calculated scalar

```java
// In-memory, from loaded props (works in DTOs/fetchers, auto-adds dependencies)
@Formula(dependencies = {"firstName", "lastName"})
default String fullName() { return firstName() + " " + lastName(); }

// SQL-level, computed in DB
@Formula(sql = "CONCAT(%alias.FIRST_NAME, ' ', %alias.LAST_NAME)")
String fullName();
```

`dependencies` may traverse associations (`"department.name"`). Prefer `dependencies` form; `sql` form cannot be used by save.

## @IdView — FK as scalar

```java
@ManyToOne
RelatedObject relatedObject();

@IdView
UUID relatedObjectId();          // view of relatedObject.id, no extra query

@IdView("labelObjects")
List<UUID> labelObjectIds();     // list association ids
```

## @ManyToManyView — deep association shortcut

```java
@OneToMany(mappedBy = "domainObject")
List<Membership> memberships();

@ManyToManyView(prop = "memberships", deeperProp = "user")
List<User> users();              // read-only many-to-many through middle entity
```

## @LogicalDeleted — soft delete

```java
@LogicalDeleted("true")          // boolean flag; deleted when true
boolean deleted();

@LogicalDeleted("now")           // timestamp; deleted when set
@Nullable Instant deletedAt();

@LogicalDeleted(generatorType = MyLongGenerator.class)  // unique tombstone values
long deletedMillis();
```

- Global filter hides deleted rows automatically; `deleteById` becomes `UPDATE` when entity has the flag (unless `DeleteMode.PHYSICAL`).
- `@KeyUniqueConstraint` upserts + logical delete — two valid schema shapes:
  - multi-version flag (timestamp/tombstone values): the DB unique constraint must include the delete-flag column (`unique(key..., deleted_millis)`) — deleted versions coexist;
  - boolean flag: a partial unique index (`unique ... where deleted = false`) works for key-based upsert on dialects that can express a conflict predicate (PostgreSQL); dialects that cannot fall back to select-then-write.
- `@JoinTable(deletedWhenEndpointIsLogicallyDeleted = true)` physically deletes middle-table rows of a logically deleted endpoint; a `@JoinTable` with its own `logicalDeletedFilter` logically deletes them instead.

## @Embeddable + @PropOverride

```java
@Embeddable
public interface Point {
    int x();
    int y();
}

// in entity
@PropOverride(prop = "x", columnName = "LEFT_X")
@PropOverride(prop = "y", columnName = "TOP_Y")
Point topLeft();
```

Embeddable props usable in DSL (`t.topLeft().x()`), DTOs (`flat(topLeft)`), and composite ids.

## @Serialized — JSON column

```java
@Serialized
List<String> tags();             // jsonb/json column, Jackson-serialized
```

## @MapsId — target id inside own id

Use when the schema itself says so: the association's FK columns ARE the owner's PK (shared-PK one-to-one) or one segment of a composite PK. It describes column identity, not naming.

```java
@Id
long messageId();                // ordinary @Id — NOT an @IdView, never annotate it as one

@MapsId                          // whole id mapped from the target
@OneToOne
@JoinColumn                      // still required (owning side); name comes from the naming strategy
Message message();
```

For composite ids, `@MapsId("pathInsideId")` maps the target id into one path of the embedded id; the other parts stay local. On save, Jimmer keeps the id property and the association consistent (set both to the same value in the draft).

Query optimization: id-oriented predicates/order/group/selections on the association reuse the owner's own columns (no join), and a mapped-id association used purely as a bridge gets its middle join removed — only where semantics (nullability, no target columns referenced) allow.

## @Transient + TransientResolver — computed association/aggregate

```java
@Transient(ref = "domainObjectCountResolver")   // bean name (or value = Resolver.class)
long childCount();
```

Resolver implements `TransientResolver<ID, V>` with batch `resolve(Collection<ID>)` — N+1 safe, cacheable.

Shared resolver across entities — resolver context (experimental, opt-in via `@ExperimentalTransientResolverContext` in Kotlin): the `resolve(ids, ctx)` overload exposes `ctx.prop` (which property/declaring type is being resolved), `ctx.connection`, `ctx.sourceIds` — one resolver implements the algorithm (e.g. tree breadcrumbs) for every concrete entity instead of one resolver class per entity. Old single-arg resolvers keep working unchanged.

## Generic mapped superclass

`@MappedSuperclass` supports self-bounded generics with `where` constraints — define recursive structure once:

```kotlin
@MappedSuperclass
interface BaseTreeNode<T> where T : BaseTreeNode<T> {
    @ManyToOne val parent: T?
    @OneToMany(mappedBy = "parent") val children: List<T>
}

@Entity
interface ProductCategory : BaseTreeNode<ProductCategory> { @Id val id: Long }
```

`parent`/`children` materialize with the concrete type (`ProductCategory`). Multiple inheritance of mapped superclasses is allowed (`BaseEntity, TenantAware`) — the tenant/audit pattern pairs with global filters and draft interceptors. Combine with resolver context: one shared resolver serves all tree entities extending the same base.

## Enum mapping

```java
@EnumType(EnumType.Strategy.NAME)   // NAME (default varchar) or ORDINAL
public enum Status {
    @EnumItem(name = "A") ACTIVE,
    @EnumItem(name = "D") DISABLED
}
```

## Misc

- `@Default("0")` — ORM-level default for unloaded primitive props.
- `@ExcludeFromAllScalars` — prop skipped by `#allScalars` in DTOs.
- `@JoinSql("...")` — custom SQL join predicate for nonstandard associations (pair with `WeakJoin` in queries).
- `@DatabaseValidationIgnore` — skip DB-schema validation for entity/prop.
- `ForeignKeyType.FAKE` on `@JoinColumn(foreignKeyType = ...)` — association without real DB FK constraint.
