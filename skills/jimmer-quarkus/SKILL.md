---
name: jimmer-quarkus
description: |
  Quarkus-specific Jimmer integration for dependencies, repository imports, JAX-RS resources, CDI services, config keys, multi-datasource, and Kotlin all-open.
triggers:
  - "Quarkus Jimmer"
  - "quarkus.jimmer"
  - "quarkus-jimmer"
  - "jimmer application.yml"
  - "jimmer config keys"
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
    database-validation-mode: NONE   # NONE | WARNING | ERROR (nested database-validation.mode is deprecated)
  # entities in a separate module need Jandex visibility:
  index-dependency:
    model:
      group-id: com.example
      artifact-id: example-model
```

### Key registry

Full registry of every `application.yml` key (shared Spring/Quarkus set, quarkus-only and spring-only markers) lives in the `jimmer-config` reference skill. Quarkus specifics in short: per-datasource keys via `quarkus.jimmer.<datasource-name>.<key>`; dialect derived from `quarkus.datasource.db-kind`; entity cache configured declaratively via `quarkus.jimmer.cache.entities`.

Native image: add `--initialize-at-run-time` for dialects touched at build time if the build complains.

## Kotlin + Quarkus

Use all-open for CDI classes:

```kotlin
allOpen {
    annotation("jakarta.enterprise.context.ApplicationScoped")
}
```

KSP processor `jimmer-ksp` must be wired; entity module needs `index-dependency` as above.
