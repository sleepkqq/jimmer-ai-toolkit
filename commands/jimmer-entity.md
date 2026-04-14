---
description: "Design a new Jimmer entity with repository"
---

# Entity Designer — STRICT WORKFLOW

## Step 1: Gather requirements

Ask the user if unclear:
- Entity name and purpose
- Fields with types
- Associations
- Whether it needs Model (updatedAt + @Version) or Auditable (createdAt only)
- Natural business key?

## Step 2: Scan existing project

Read existing entities, repositories, package structure. Match code style exactly.

## Step 3: Design the entity

Field order: @Id → primary fields → secondary → audit → associations last.

- `@JoinColumn` directly under association annotation
- `@Nullable` (org.jetbrains.annotations) for nullable fields. Non-null by default
- Jimmer auto-maps camelCase → snake_case — no `@Column` needed
- `@Key` + `@KeyUniqueConstraint` for natural keys
- `@OnDissociate(DissociateAction.DELETE)` on owned children's FK

## Step 4: Generate the repository

Generate an empty interface extending JRepository:

```java
public interface ArticleRepository extends JRepository<Article, UUID> {
}
```

JRepository already provides: `findNullable`, `findById`, `save`, `deleteById`, `findAll`, `viewer()`, `saveCommand()`.

Add custom methods only when the user explicitly asked for a specific query. For queries, use `/jimmer-build-query`.

## Step 5: Compile

Check the project root:
- `./gradlew` exists → `./gradlew compileJava` / `compileKotlin`
- `./mvnw` exists → `./mvnw compile`
- neither → `gradle` / `mvn`

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
