---
name: jimmer-inheritance
description: Model shared entity properties with Jimmer Java/Kotlin mapped superclasses and recognize unsupported polymorphic inheritance, discriminators and subtype DTOs.
metadata:
  toolkit: jimmer-ai-toolkit
  kind: task
---

# Shared models and inheritance

The official release supports `@MappedSuperclass` property reuse. It does **not** support `@Inheritance(SINGLE_TABLE/JOINED)`, `@Discriminator`, `@DiscriminatorValue`, subtype `forType` fetching, `treatAs` queries, `TypeMatchMode`, type-changing saves or DTO `#types` branches.

Do not produce non-compiling newer annotations. First distinguish common fields from a genuinely polymorphic identity/query requirement.

Java (separate source files):

```java
@MappedSuperclass
public interface Named {
    String name();
}

@Entity
public interface Book extends Named {
    @Id long id();
    String isbn();
}
```

Kotlin (one model interface per source file, required by this release's KSP):

```kotlin
@MappedSuperclass
interface Named {
    val name: String
}

@Entity
interface Book : Named {
    @Id val id: Long
    val isbn: String
}
```

Each concrete entity has its own mapping/query root. A mapped superclass does not create a table, discriminator, cross-type query or database-wide identity. Put shared audit/tenant/version properties there only when all consumers actually share their semantics.

If the requirement is polymorphic persistence, explicitly identify the unsupported capability. Depending on the real schema, use ordinary entity associations/composition and application-level result types, or plan an explicit release upgrade. A Kotlin sealed response interface or Java result hierarchy is not ORM entity inheritance. Preserve subtype-specific validation and uniqueness; do not make every field nullable merely to silence the processor.

Verify APT and KSP generation for shared properties, independent entity queries and actual migrations. Read `jimmer-entity` and `jimmer-dto` for the supported mapping/projection paths.

Source: [MappedSuperclass](https://github.com/babyfish-ct/jimmer/blob/v0.9.111/project/jimmer-core/src/main/java/org/babyfish/jimmer/sql/MappedSuperclass.java), [available annotations](https://github.com/babyfish-ct/jimmer/tree/v0.9.111/project/jimmer-core/src/main/java/org/babyfish/jimmer/sql).
