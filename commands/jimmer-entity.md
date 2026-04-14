---
description: "Design a new Jimmer entity with repository"
---

# Entity Designer — STRICT WORKFLOW

## Step 1: Gather requirements

Ask the user if unclear:
- Entity name and purpose
- Fields with types
- Associations
- Natural business key?

## Step 2: Scan existing project

Search the project for interfaces annotated with `@MappedSuperclass` — these are the project's base entities. Note their names, fields, and what they provide (audit timestamps, @Version, etc.).

- Found → use them when designing the new entity
- Not found → ask the user whether they want a base entity, and suggest two common patterns: `Auditable` (createdAt only) and `Model extends Auditable` (adds updatedAt + @Version)

Read existing entities, repositories, and package structure. Match code style exactly.

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

Run `ls gradlew mvnw 2>/dev/null` in the project root and use the result:
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
