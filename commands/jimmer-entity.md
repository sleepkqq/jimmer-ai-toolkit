---
description: "Design a new Jimmer entity with repository"
---

# Entity Designer — STRICT WORKFLOW

## Step 1: Gather requirements

If the user's request is missing any of the following — ask before doing anything else:
- Entity name and purpose
- Fields with names and types
- Associations to other entities
- Natural business key?

Do not proceed to Step 2 until these are clear.

## Step 2: Scan existing project

Collect the following in one pass:

1. **Build tool** — run `ls gradlew mvnw 2>/dev/null` in the project root. Note the result for Step 5.
2. **Base entities** — search for `@MappedSuperclass`. Note their names and what fields they provide.
3. **Package structure and code style** — read several existing entities and repositories to match naming, imports, annotations style exactly.

## Step 3: Design the entity

Field order: @Id → primary fields → secondary → audit → associations last.

- `@JoinColumn` directly under association annotation
- `@Nullable` (org.jetbrains.annotations) for nullable fields. Non-null by default
- Jimmer auto-maps camelCase → snake_case — no `@Column` needed
- `@Key` + `@KeyUniqueConstraint` for natural keys
- `@OnDissociate(DissociateAction.DELETE)` on owned children's FK

**Base entity inheritance:**
- `@MappedSuperclass` found in Step 2 → use the appropriate one
- None found → ask the user if they want one, suggest: `Auditable` (createdAt only) and `Model extends Auditable` (adds updatedAt + @Version)

## Step 4: Generate the repository

Always generate an empty interface:

```java
public interface ArticleRepository extends JRepository<Article, UUID> {
}
```

JRepository already provides: `findNullable`, `findById`, `save`, `deleteById`, `findAll`, `viewer()`, `saveCommand()`.

Other repositories in the project having custom methods is not a reason to add methods here. Add custom methods only when the user explicitly asked for a specific query on this entity. For queries use `/jimmer-build-query`.

## Step 5: Compile

Use the build tool detected in Step 2:
- `gradlew` → `./gradlew compileJava` / `./gradlew compileKotlin`
- `mvnw` → `./mvnw compile`
- neither → `gradle compileJava` / `mvn compile`

Fix errors. Done.

---

## Output

1. Entity interface
2. Repository interface
3. Warnings if any

For .dto files use `/jimmer-dto`. For migrations use `/jimmer-migration`.

---

## Project Setup Reference

| Jimmer | Spring Boot | Min JDK |
|---|---|---|
| 0.10.x | 4.x only | 17 |
| 0.9.x (use 0.9.120) | 3.x | 17 |

| Framework | Starter | Annotation Processor |
|---|---|---|
| Spring Boot Java | `jimmer-spring-boot-starter` | `jimmer-apt` |
| Spring Boot Kotlin | `jimmer-spring-boot-starter` | `jimmer-ksp` |
