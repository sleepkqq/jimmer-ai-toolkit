---
name: jimmer-quarkus
description: |
  Quarkus-specific Jimmer integration for dependencies, repository imports, JAX-RS resources, CDI services, config keys, multi-datasource, and Kotlin all-open.
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

Use when target project uses Quarkus with Jimmer (extension: `io.quarkiverse.jimmer:quarkus-jimmer`).

## Differences From Spring Boot

| Aspect | Spring Boot | Quarkus |
|---|---|---|
| Starter | `jimmer-spring-boot-starter` | `jimmer-sql` / `jimmer-sql-kotlin` + `quarkus-jimmer` |
| Config prefix | `jimmer.*` | `quarkus.jimmer.*` |
| DI | `@Service`, `@Component` | `@ApplicationScoped` |
| REST | `@RestController`, `@GetMapping` | `@Path`, `@GET`, JAX-RS |
| Repository import | `org.babyfish.jimmer.spring.repository.*` | `io.quarkiverse.jimmer.runtime.repository.*` |

CDI beans of type `DraftInterceptor`, `DraftPreProcessor`, `Filter`, `ExceptionTranslator`, `TransientResolver` are auto-discovered and registered into the sql client.

The extension ships `io.quarkiverse.jimmer.runtime.generator.UUIDv7IdGenerator` — prefer it over plain `UUIDIdGenerator` for time-ordered UUID primary keys.

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
    language: kotlin            # java | kotlin
    show-sql: true
    pretty-sql: true
    database-validation:
      mode: NONE                # NONE | WARNING | ERROR
  # entities in a separate module need Jandex visibility:
  index-dependency:
    model:
      group-id: com.example
      artifact-id: example-model
```

Other keys: `quarkus.jimmer.error-translator.*`, dialect and batch sizes per datasource; multiple datasources via `quarkus.jimmer.<datasource-name>.*`. Dialect is normally derived from `quarkus.datasource.db-kind`.

Native image: add `--initialize-at-run-time` for dialects touched at build time if the build complains.

## Kotlin + Quarkus

Use all-open for CDI classes:

```kotlin
allOpen {
    annotation("jakarta.enterprise.context.ApplicationScoped")
}
```

KSP processor `jimmer-ksp` must be wired; entity module needs `index-dependency` as above.
