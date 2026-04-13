---
description: "Design a new Jimmer entity with repository"
---

# Entity Designer

Design a Jimmer entity following best practices.

## Adaptation

Before generating, scan existing project source files and match code style, package structure, and patterns. Follow the project's conventions — don't impose your own.

## Process

1. **Gather requirements** — ask the user:
   - Entity name and purpose
   - Fields with types (String, Int, UUID, Instant, enum, JSON, etc.)
   - Associations (belongs-to, has-many, one-to-one, many-to-many)
   - Whether it needs update tracking (Model) or just creation time (Auditable)
   - Whether it has a natural business key

2. **Design the entity** following the field ordering convention:
   - `@Id` first (determine generation strategy — use built-in `UUIDIdGenerator`, never create custom)
   - Primary business fields
   - Secondary fields
   - All associations last (with `@JoinColumn` under the association annotation)

3. **Apply annotations:**
   - `@Key` + `@KeyUniqueConstraint` if natural key exists
   - `@OnDissociate(DissociateAction.DELETE)` on owned `@OneToMany` collections
   - `@Serialized` for JSON columns
   - `@Table` only if table name differs from snake_case entity name
   - **NEVER add `@Column`** — Jimmer auto-maps camelCase → snake_case (`impactLevel` → `impact_level`)
   - `@Nullable` (org.jetbrains.annotations) for nullable fields — non-null by default

4. **Generate the Repository:**
   - Java: `JRepository<Entity, UUID>`, Kotlin: `KRepository<Entity, UUID>`
   - Generate ONLY methods the user asked for — don't add findBy* for every field
   - Don't reimplement built-in methods (findNullable, save, findAll)

5. **Verify** — field ordering, @JoinColumn placement, @OnDissociate on owned collections

6. **Compile** (`./mvnw compile` or `./gradlew build`). Fix errors before finishing.

**Do NOT generate .dto files** — use `/jimmer-dto` for that separately.
**Do NOT generate migrations** — use `/jimmer-migration` for that separately.

## Output Format

Provide:
1. Entity interface code
2. Repository interface (only custom methods)
3. Any warnings about potential issues

---

# Project Setup Reference

## Version Compatibility

| Jimmer | Spring Boot | Kotlin | KSP | Gradle | Min JDK |
|---|---|---|---|---|---|
| 0.10.x | **4.x only** | 2.1+ | 2.1+ | 8.12+ | 17 |
| 0.9.x (use 0.9.120) | 3.x | 1.9+ / 2.0+ | 1.9+ / 2.0+ | 8.0+ | 17 |

## Dependency Matrix

| Framework | Language | Starter | Annotation Processor |
|---|---|---|---|
| Spring Boot | Java | `jimmer-spring-boot-starter` | `jimmer-apt` (Maven APT) |
| Spring Boot | Kotlin | `jimmer-spring-boot-starter` | `jimmer-ksp` (Gradle KSP) |
| Quarkus | Java | `quarkus-jimmer` (extension) | `jimmer-apt` (Maven APT) |
| Quarkus | Kotlin | `quarkus-jimmer` (extension) | `jimmer-ksp` (Gradle KSP) |

## Multi-Module Structure

```
my-project/
├── my-project-model/        # Entities, repositories, DTOs, migrations
│   ├── src/main/kotlin/     # (or java/)
│   │   └── entity/
│   │   └── repository/
│   ├── src/main/dto/        # .dto files
│   └── src/main/resources/
│       └── db/              # Liquibase/Flyway migrations
├── my-project-service/      # Business logic, REST resources
└── build.gradle.kts         # or pom.xml
```

**Key rule:** `jimmer-ksp`/`jimmer-apt` annotation processor goes only in the model module.

## Injection Quick Reference

| Stack | Code |
|---|---|
| Spring Boot + Java | `@Service @RequiredArgsConstructor class MyService { private final JSqlClient sql; }` |
| Quarkus + Java | `@ApplicationScoped class MyService { @Inject JSqlClient sql; }` |
