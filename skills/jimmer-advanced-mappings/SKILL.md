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
- `@KeyUniqueConstraint` upserts require the DB unique constraint to include the logical-delete flag column.
- `@JoinTable(deletedWhenEndpointIsLogicallyDeleted = true)` cascades to middle tables.

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

```java
@MapsId                          // this reference's target id == this entity's id
@OneToOne
User user();
```

For composite ids, `@MapsId("pathInsideId")` maps into a part of the id. Jimmer optimizes joins through such references (no extra join).

## @Transient + TransientResolver — computed association/aggregate

```java
@Transient(ref = "domainObjectCountResolver")   // bean name (or value = Resolver.class)
long childCount();
```

Resolver implements `TransientResolver<ID, V>` with batch `resolve(Collection<ID>)` — N+1 safe, cacheable.

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
