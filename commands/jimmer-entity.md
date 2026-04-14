---
description: "Design a new Jimmer entity with repository"
---

# Entity Designer — STRICT WORKFLOW

## Step 1: Scan existing project

Collect the following in one pass before asking anything:

1. **Base entities** — search for `@MappedSuperclass`. Note their names and what fields they provide.
2. **Package structure and code style** — read several existing entities and repositories for naming, imports, annotation style. Read repositories for style only — what methods other repositories have is irrelevant to this task.

## Step 2: Gather requirements

Using what was found in Step 1 as context, ask the user about anything still unclear:
- Entity name and purpose
- Fields with names and types
- Associations to other entities
- Natural business key?

If the project's existing entities make some answers obvious — don't ask, infer. Only ask what cannot be determined from the project.

## Step 3: Design the entity

Field order: @Id → primary fields → secondary → audit → associations last.

- `@JoinColumn` directly under association annotation
- `@Nullable` (org.jetbrains.annotations) for nullable fields. Non-null by default
- Jimmer auto-maps camelCase → snake_case — no `@Column` needed
- `@Key` + `@KeyUniqueConstraint` for natural keys
- `@OnDissociate(DissociateAction.DELETE)` on owned children's FK

**Base entity inheritance:**
- `@MappedSuperclass` found in Step 1 → ask the user whether this entity needs audit/base fields. If yes — extend the base entity. If no — leave extends out. `@Entity` is always present regardless.
- None found → ask the user if they want a base entity and suggest two patterns: `Auditable` (createdAt only) and `Model extends Auditable` (adds updatedAt + @Version)

## Step 4: Update existing entities

For every association on the new entity, open the existing entity file and add the reverse side. Association syntax and `mappedBy` rules are in `instructions/jimmer-entity-design.md` → Associations section.

## Step 5: Generate the repository

Output this, replacing only the entity name:

```java
public interface ArticleRepository extends JRepository<Article, UUID> {
}
```

The body is empty. The only reason to add a method is if the current task explicitly requires a query that JRepository built-ins cannot handle and that method is called in code written right now. If that condition is not met — the body stays empty.

## Step 6: Compile

Execute `ls gradlew mvnw 2>/dev/null` as a tool call and wait for the output. The build command is chosen strictly from that output — do not assume a wrapper exists before seeing the result:
- output contains `gradlew` → `./gradlew compileJava` / `./gradlew compileKotlin`
- output contains `mvnw` → `./mvnw compile`
- output is empty → check for `pom.xml` → `mvn compile`, or `build.gradle` → `gradle compileJava` / `gradle compileKotlin`

Fix errors. Done.

---

## Output

1. New entity interface
2. Updated existing entities (reverse associations)
3. Repository interface
4. Warnings if any

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
