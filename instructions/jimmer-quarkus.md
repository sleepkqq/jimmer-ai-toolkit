# Jimmer Quarkus Reference

This file supplements the main toolkit for Quarkus projects. Import it when working with Quarkus + Jimmer.

## Key Differences from Spring Boot

### Dependencies

| Aspect | Spring Boot | Quarkus |
|---|---|---|
| Starter | `jimmer-spring-boot-starter` | `jimmer-sql` / `jimmer-sql-kotlin` + `quarkus-jimmer` extension |
| Config prefix | `jimmer.*` | `quarkus.jimmer.*` |
| DI annotations | `@Service`, `@Component` | `@ApplicationScoped` |
| REST | `@RestController` + `@GetMapping` | `@Path` + `@GET` (JAX-RS) |
| Repository import | `org.babyfish.jimmer.spring.repository.*` | `io.quarkiverse.jimmer.runtime.repository.*` |

### REST Layer — Resource (not Controller)

```java
@Path("/articles")
@ApplicationScoped
public class ArticleResource {

    @Inject
    ArticleService service;

    @GET
    public List<ArticleListView> findAll() {
        return service.findAll();
    }

    @POST
    public ArticleDetailView create(ArticleCreateInput input) {
        return service.create(input);
    }

    @GET
    @Path("/{id}")
    public ArticleDetailView findById(@PathParam("id") UUID id) {
        return service.findById(id);
    }
}
```

### Service Layer

```java
@ApplicationScoped
public class ArticleService {
    @Inject
    ArticleRepository repository;
    // same business logic as Spring Boot
}
```

### Configuration

```yaml
quarkus:
  jimmer:
    language: kotlin  # only if Kotlin
    dialect: org.babyfish.jimmer.sql.dialect.PostgresDialect
    show-sql: true
```

### Kotlin + Quarkus — allopen plugin

```kotlin
plugins {
    kotlin("plugin.allopen")
}
allOpen {
    annotation("jakarta.enterprise.context.ApplicationScoped")
}
```
