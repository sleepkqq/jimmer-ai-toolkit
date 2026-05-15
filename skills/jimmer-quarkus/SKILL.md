---
name: jimmer-quarkus
description: |
  Quarkus-specific Jimmer integration for dependencies, repository imports, JAX-RS resources, CDI services, config, and Kotlin all-open.
triggers:
  - "Quarkus Jimmer"
  - "quarkus.jimmer"
  - "quarkus-jimmer"
  - "JAX-RS Jimmer"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Quarkus

Use when target project uses Quarkus with Jimmer.

## Differences From Spring Boot

| Aspect | Spring Boot | Quarkus |
|---|---|---|
| Starter | `jimmer-spring-boot-starter` | `jimmer-sql` / `jimmer-sql-kotlin` + `quarkus-jimmer` |
| Config prefix | `jimmer.*` | `quarkus.jimmer.*` |
| DI | `@Service`, `@Component` | `@ApplicationScoped` |
| REST | `@RestController`, `@GetMapping` | `@Path`, `@GET`, JAX-RS |
| Repository import | `org.babyfish.jimmer.spring.repository.*` | `io.quarkiverse.jimmer.runtime.repository.*` |

## Resource Layer

```java
@Path("/domain-objects")
@ApplicationScoped
public class DomainObjectResource {
    @Inject
    DomainObjectService service;

    @GET
    public List<DomainObjectListView> findAll() {
        return service.findAll();
    }

    @POST
    public DomainObjectDetailView create(DomainObjectCreateInput input) {
        return service.create(input);
    }
}
```

## Service Layer

```java
@ApplicationScoped
public class DomainObjectService {
    @Inject
    DomainObjectRepository repository;
}
```

## Config

```yaml
quarkus:
  jimmer:
    language: kotlin
    dialect: org.babyfish.jimmer.sql.dialect.PostgresDialect
    show-sql: true
```

## Kotlin + Quarkus

Use all-open for CDI classes:

```kotlin
allOpen {
    annotation("jakarta.enterprise.context.ApplicationScoped")
}
```
