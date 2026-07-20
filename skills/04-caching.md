# Caching

---

## Goal

Views look **already loaded** when opened. The user never stares at a spinner if data was previously fetched. Network updates arrive in the background and update the UI automatically.

---

## The cache-first streaming pattern

The repository emits data in two phases via `AsyncThrowingStream`:

```
Phase 1 (instant):  yield cached data (from disk/memory/bundled JSON)
Phase 2 (network):  yield fresh data after API call completes
Stream finishes.
```

The ViewModel advances through states as emissions arrive:

```
.loading → .loaded(cachedData) → .loaded(freshData)
           ↑ view renders here    ↑ view updates silently
```

---

## Repository implementation

```swift
public func getSupportData() -> AsyncThrowingStream<SupportData, Error> {
    return AsyncThrowingStream { continuation in
        Task {
            var lastEmitted: SupportData?

            do {
                // Phase 1: serve from cache or bundled default
                if let cached = try await localDataSource.load() {
                    yieldIfChanged(cached, lastEmitted: &lastEmitted, continuation: continuation)
                } else {
                    let bundled = try await bundledDataSource.loadDefault()
                    yieldIfChanged(bundled, lastEmitted: &lastEmitted, continuation: continuation)
                }

                // Phase 2: fetch from network
                do {
                    let fresh = try await api.fetchSupportData().toModel()
                    try await localDataSource.save(fresh)
                    yieldIfChanged(fresh, lastEmitted: &lastEmitted, continuation: continuation)
                    continuation.finish()
                } catch {
                    // API failed but user already sees cached data — finish gracefully
                    // SentrySDK.capture(error: error) — do this in the adapter layer
                    continuation.finish()
                }
            } catch {
                continuation.finish(throwing: error)   // no data at all — propagate
            }
        }
    }
}

private func yieldIfChanged(
    _ data: SupportData,
    lastEmitted: inout SupportData?,
    continuation: AsyncThrowingStream<SupportData, Error>.Continuation
) {
    guard lastEmitted != data else { return }
    lastEmitted = data
    continuation.yield(data)
}
```

### Key behaviours

| Scenario | Result |
|----------|--------|
| Cache exists, API succeeds | Emit cached → emit fresh → finish |
| Cache exists, API fails | Emit cached → finish (no error thrown) |
| No cache, API succeeds | Emit bundled → emit fresh → finish |
| No cache, API fails | Emit bundled → finish (no error thrown) |
| No cache, no bundled data | Throw error → ViewModel shows `.error` state |
| Cached == fresh (unchanged) | Only one emission (deduplication via `yieldIfChanged`) |

---

## Two-event enum pattern (Vehicle repository)

When cached and loaded data are semantically different (e.g. "still loading vs fully loaded"), use a named enum instead of emitting the same type twice:

```swift
public enum VehicleLoadEvent: Equatable, Sendable {
    case cached([VehicleData])   // from local store — may be incomplete
    case loaded([VehicleData])   // from network — authoritative
}

public func loadVehicles(_ strategy: VehicleLoadingStrategy) async -> AsyncThrowingStream<VehicleLoadEvent, Error> {
    AsyncThrowingStream { continuation in
        Task {
            switch strategy {
            case .local:
                continuation.yield(.loaded(await getCachedVehicles()))
            case .remote:
                continuation.yield(.loaded(try await fetchVehicles()))
            case .complete:
                let cached = await getCachedVehicles()
                if !cached.isEmpty { continuation.yield(.cached(cached)) }
                continuation.yield(.loaded(try await fetchVehicles()))
            }
            continuation.finish()
        }
    }
}
```

ViewModel handles both cases:

```swift
for try await event in stream {
    switch event {
    case .cached(let vehicles):
        // Show immediately — user isn't waiting
        vehicleList = vehicles.map { VehicleInfo($0) }
    case .loaded(let vehicles):
        // Authoritative update
        vehicleList = vehicles.map { VehicleInfo($0) }
        state = vehicles.isEmpty ? .noVehicles : .loaded(makeVehicleState(vehicles))
    }
}
```

---

## DataSource protocol

Every caching layer is abstracted behind a `DataSource` protocol, making it trivially swappable between disk, memory, and mock:

```swift
public protocol <Domain>DataSource {
    func load() async throws -> <Domain>Data?
    func save(_ data: <Domain>Data) async throws
    func clear() async throws
}
```

### `JsonFile<Domain>DataSource` — disk persistence

```swift
public final class JsonFileSupportDataSource: SupportDataSource {
    private var fileURL: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("support_\(locale.cacheFileName)")
    }

    public func load() async throws -> SupportData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try JSONDecoder().decode(SupportData.self, from: Data(contentsOf: fileURL))
        } catch {
            try? FileManager.default.removeItem(at: fileURL)   // delete corrupt cache
            return nil
        }
    }

    public func save(_ data: SupportData) async throws {
        let json = try JSONEncoder().encode(data)
        try json.write(to: fileURL, options: .atomic)
    }
}
```

### `InMemory<Domain>DataSource` — actor-isolated in-memory cache

```swift
public actor VehicleRepositoryImpl: VehicleRepository {
    private var cachedVehicles: [VehicleData] = []

    public func getCachedVehicles() async -> [VehicleData] {
        if !cachedVehicles.isEmpty { return cachedVehicles }
        if let disk = try? await localDataSource.load(), !disk.isEmpty {
            cachedVehicles = disk
            return disk
        }
        return []
    }
}
```

---

## In-flight deduplication

Prevent multiple concurrent network calls for the same resource:

```swift
private var inFlightRefresh: Task<[VehicleData], Error>?

public func fetchVehicles() async throws -> [VehicleData] {
    if let inFlightRefresh {
        return try await inFlightRefresh.value   // join existing task
    }
    let task = Task<[VehicleData], Error> {
        let data = try await api.fetchVehicles()
        await storeVehicles(data.map { $0.toModel() })
        return data.map { $0.toModel() }
    }
    inFlightRefresh = task
    defer { inFlightRefresh = nil }
    do {
        return try await task.value
    } catch {
        let cached = await getCachedVehicles()
        if !cached.isEmpty { return cached }    // fallback to cache on error
        throw error
    }
}
```

---

## Bundled default data

Ship a default JSON file inside `Resources/` so the first launch shows real content before any network call:

```
Data-<Domain>/Sources/Data<Domain>/Resources/
  support_sv.json     ← Swedish default
  support_en.json     ← English default
```

```swift
open class BundledSupportDataSource {
    open func loadDefault() async throws -> SupportData {
        let locale = SupportLocale()
        guard let url = Bundle.module.url(forResource: locale.defaultResourceName, withExtension: "json") else {
            throw NSError(domain: "BundledDataSource", code: 404)
        }
        return try JSONDecoder().decode(SupportData.self, from: Data(contentsOf: url))
    }
}
```

Mark the class `open` so tests can subclass and override `loadDefault()` without a real bundle.

---

## Cache invalidation

| Trigger | Action |
|---------|--------|
| User logs out | Call `repository.reset()` — clears disk and memory |
| User pulls to refresh | Call `repository.reload()` — clears cache, next `loadVehicles(.remote)` fetches fresh |
| App foregrounds | Call `loadData()` with `.complete` strategy — emits cached first, then refreshes |
| Data changes on server | Repository's network phase emits updated data automatically |

---

## Storage technology — JSON vs CoreData / SwiftData

The default caching strategy uses JSON files on disk via `JsonFile<Domain>DataSource`. This is intentional — JSON is simple, debuggable, and sufficient for most use cases.

**Stick with JSON when:**
- The cached data is a single snapshot replaced wholesale on each refresh (e.g. a list fetched from an API)
- The dataset is small (< a few hundred items)
- No querying, filtering, or relationships between entities are needed
- The structure changes frequently during early development

**Consider upgrading to CoreData or SwiftData when:**
- The dataset is large and needs partial updates or incremental sync rather than full replacement
- The app needs to query, filter, or sort cached data efficiently (e.g. full-text search, date-range queries)
- Multiple entities have relationships that need to be maintained (e.g. orders → line items → products)
- Offline editing or conflict resolution is required

When upgrading, replace only `<Domain>DataSource` — the `Repository`, `Api`, and `DataModule` layers remain unchanged since they depend on the `DataSource` protocol, not the implementation.

> **When implementing a new cache, always reconsider** whether JSON is still appropriate or whether the data access patterns warrant CoreData/SwiftData. Do not add complexity prematurely, but do not defer the decision so long that migrating becomes costly.

---

## Rules

1. Never block the UI waiting for a network call — always emit cached/bundled data first
2. `DataSource.load()` never throws for "no data" — return `nil`, throw only for unexpected errors (e.g. corrupt data that also fails cleanup)
3. API failures during background refresh are caught and finished gracefully — do not re-throw into the stream when initial data was already yielded
4. Use `yieldIfChanged` to avoid redundant UI redraws when cached and fresh data happen to be equal
5. The `actor` keyword on repository implementations with `var cachedVehicles` ensures no data races
6. Default to JSON caching; upgrade to CoreData/SwiftData only when querying, relationships, or large dataset performance require it
