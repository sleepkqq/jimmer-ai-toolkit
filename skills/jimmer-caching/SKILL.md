---
name: jimmer-caching
description: |
  Jimmer entity cache guide: object/association/calculated cache kinds, CacheFactory + ChainCacheBuilder wiring (Caffeine L1 + Redis L2), BinLog vs Transaction trigger consistency, multi-view caches with SubKey for user filters, abandoned-cache diagnostics.
triggers:
  - "Jimmer cache"
  - "entity cache"
  - "CacheFactory"
  - "association cache"
  - "calculated cache"
  - "multi-view cache"
  - "SubKey"
  - "cache invalidation"
jimmer:
  toolkit: jimmer-ai-toolkit
  kind: reference
---

# Jimmer Caching

ORM-level entity cache, distinct from any application-level cache (`@CacheResult` etc.). Invalidation is driven by Jimmer triggers — never hand-invalidate entity caches.

## Cache kinds

| Kind | Key → Value | Created by | Invalidation |
|---|---|---|---|
| Object cache | `Type-id` → entity row | `createObjectCache(type)` | automatic on DML |
| Association cache | `Type.prop-ownerId` → target id(s) | `createAssociatedIdCache` / `createAssociatedIdListCache` | automatic on DML (both FK sides / middle table) |
| Calculated cache | `Type.prop-id` → resolver value | `createResolverCache` | user-assisted (resolver reacts to trigger events) |

Association + calculated together = "property caches" — only they can be multi-view; object cache is always single-view.

## Wiring

Implement `CacheFactory` (Java) / `KCacheFactory` (Kotlin); build each cache with `ChainCacheBuilder` — one `.add(binder)` per tier, any depth (two tiers is the norm):

```kotlin
override fun createObjectCache(type: ImmutableType): Cache<*, *>? =
    ChainCacheBuilder<Any, Any>()
        .add(CaffeineValueBinder.forObject(type).maximumSize(512).duration(10.seconds).build())
        .add(RedisValueBinder.forObject(type).redis(connectionFactory).objectMapper(objectMapper).duration(10.hours).build())
        .build()
```

Returning `null` from a `create*Cache` method = that type/prop is simply uncached (per-type opt-out lives here). Register via framework config (Spring bean) or `setCacheFactory` on the sql client builder.

## Consistency — trigger-driven invalidation

| trigger-type | Mechanism | Guarantees / requirements |
|---|---|---|
| `BINLOG_ONLY` / `BOTH` (recommended by docs) | consume DB binlog from an MQ, call Jimmer's `BinLog` API → fires all trigger callbacks incl. invalidation | commit MQ offset only after the BinLog call → at-least-once invalidation; catches out-of-band DB writes too |
| `TRANSACTION_ONLY` | invalidations queued in the auto-created `JIMMER_TRANS_CACHE_OPERATOR` table inside the SAME local transaction; a `Flush` runs right after commit and periodically retries leftovers | only writes through Jimmer's API invalidate; requires an explicit dialect (DefaultDialect throws); retry interval `jimmer.transaction-cache-operator-fixed-delay` (ms) |

Either way: cache deletion is guaranteed to eventually succeed — do not add manual eviction "just in case".

## Multi-view caches — user filters

A user-defined global filter on an entity makes every association cache TARGETING it, and every calculated cache relying on those, filter-sensitive:

- Such properties either stay uncached or become multi-view — a single-view cache configured for them is IGNORED (Jimmer reports the reason via the abandoned-cache callback; wire it up and read it instead of guessing).
- Multi-view storage adds a `SubKey` dimension: `Key → SubKey → Value`, where SubKey encodes the filter arguments (e.g. `{"tenant":"a"}`), so each client view caches separately.
- The filter must implement the cacheable-filter contract (provide its SubKey parameters) for its target's property caches to stay cacheable.

Cost model: multi-view multiplies entries per key by the number of distinct filter views — reserve it for genuinely per-view data (tenancy, permissions), keep hot shared data single-view.

## Sharp edges

- Calculated (`@Transient` resolver) caches don't invalidate themselves — the resolver must subscribe to relevant trigger events and evict its own entries.
- Object cache serves id-based loads and fetcher joins; queries by arbitrary predicates still hit the DB — the cache accelerates shape assembly, not WHERE clauses.
- Bulk operations under an active cache/trigger degrade to row-aware plans so events can fire (see jimmer-performance: `CANNOT_DELETE_DIRECTLY`).
- Redis tier: helper binders (`RedisValueBinder`, tracking variants) handle serialization via the provided `ObjectMapper` — entity types must stay Jackson-serializable.
