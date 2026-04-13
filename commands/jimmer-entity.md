---
description: "Design a new Jimmer entity with .dto file and repository"
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
   - Do NOT add `@Column` — Jimmer auto-maps camelCase → snake_case (e.g., `timeCreated` → `time_created`)

4. **Generate .dto file** — only the DTOs that are needed right now:
   - Create `src/main/dto/{EntityName}.dto` with **one export per file** (only this entity)
   - Generate only what the user asked for. Typical set for CRUD:
     - `{Entity}View` — if only one view is needed
     - `{Entity}ListView` + `{Entity}DetailView` — if list and detail endpoints differ
     - `input {Entity}CreateInput` — if creation is needed
     - `input {Entity}UpdateInput` — if update is needed (include id and version if @Version)
   - Do NOT generate all 4 by default — ask what's needed or infer from context
   - Do NOT create generic "Input" with `#allScalars` — be specific about fields

5. **Generate the Repository:**
   - Kotlin: extend `KRepository<Entity, UUID>` (preferred), use default methods for complex queries
   - Java: extend `JRepository<Entity, UUID>` (preferred), use default methods for complex queries
   - Use generic `viewType` parameter — never hardcode View classes
   - Don't reimplement built-in methods (findNullable, save, findAll) — use them directly
   - Don't generate all possible `findBy*` methods — only add what's needed right now
   - If project already uses raw KSqlClient/JSqlClient pattern, follow that instead

6. **Verify** the design:
   - Field ordering correct?
   - @JoinColumn placement correct?
   - @OnDissociate on all owned collections?
   - No @Key on @OneToOne shared children?
   - DraftInterceptor in model module (if needed)?

**Do NOT generate database migrations** — use `/jimmer-migration` for that separately.

## Output Format

Provide:
1. Entity interface code
2. `.dto` file with only the DTOs needed for the current task
3. Repository interface (only custom methods, don't reimplement built-ins)
4. Any warnings about potential issues

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
| Spring Boot + Kotlin | `@Service class MyService(private val sql: KSqlClient)` |
| Spring Boot + Java | `@Service @RequiredArgsConstructor class MyService { private final JSqlClient sql; }` |
| Quarkus + Kotlin | `@ApplicationScoped class MyService(@Default val sql: KSqlClient)` |
| Quarkus + Java | `@ApplicationScoped class MyService { @Inject JSqlClient sql; }` |

