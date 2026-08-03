# Architecture

---

## Module layer graph

```
App (main Xcode target)
 ├── Feature-* SPM packages  (SwiftUI screens + ViewModels)
 │    ├── depends on: Data-* (protocols only) + Core-DesignSystem
 │    ├── may depend on: other Feature-* packages only when acting as a container (e.g. Home importing sub-features)
 │    └── NEVER depends on: App target
 ├── Data-* SPM packages     (repositories + APIs + caches)
 │    ├── depends on: Core-Networking (NetworkClient protocol + shared types)
 │    └── NEVER depends on: App target, Feature-* packages, or other Data-* packages
 └── Core-* SPM packages     (DesignSystem tokens + components; Core-Networking; Core-Analytics; Core-Logging; Core-Extensions; no business logic)
```

The App target is the only place that knows about all modules and wires them together via DI factories.

---

## Data module — internal folder structure

Every `Data-<Domain>` package follows this layout:

```
Data-<Domain>/
  Package.swift                        ← depends on Core-Networking; one library product; one test target
  Sources/Data<Domain>/
    API/
      <Domain>Api.swift                ← protocol <Domain>Api + Impl (calls networkClient.request)
    Data/
      <Domain>DataSource.swift         ← protocol (load/save/clear) + JsonFile impl + optional InMemory impl
      <Domain>Repository.swift         ← protocol + Impl; owns cache strategy; streams AsyncThrowingStream
    Models/
      <Domain>Models.swift             ← domain structs (Codable, Equatable) + DTOs + toModel() extensions
    DI/
      <Domain>DataModule.swift         ← factory; lazy var dependency graph; exposes make<Domain>Repository()
    Resources/                         ← bundled default JSON for offline fallback (optional)
  Tests/Data<Domain>Tests/             ← unit tests; mocks are private inside each test file
```

### `Core-Analytics` — shared analytics protocol package

`Core-Analytics` is a Core-layer SPM package that defines the `AnalyticsTracking` protocol and event types. Feature modules depend on the protocol only; the App target provides the concrete Firebase Analytics implementation.

```
Core-Analytics/
  Package.swift                        ← zero external deps; one library product
  Sources/CoreAnalytics/
    AnalyticsTracking.swift            ← protocol AnalyticsTracking { func track(event: AnalyticsEvent) }
    AnalyticsEvent.swift               ← enum or struct for typed events
```

Each Feature module defines its own `<Domain>AnalyticsTracking` protocol (scoped to its own events) that the App target satisfies with a concrete adapter wrapping `CoreAnalytics.AnalyticsTracking`. The concrete Firebase implementation lives in the App target and is never imported by modules.

---

### `Core-Networking` — shared networking protocol package

`Core-Networking` is a Core-layer SPM package that defines the shared `NetworkClient`
protocol, `HTTPMethod`, `NetworkError`, and `Reachability` types. All Data modules
import it instead of each owning a local copy. Concrete transport and path monitoring
stay in the App target so this package remains Foundation-only (no `Network` framework).

```
Core-Networking/
  Package.swift                        ← zero external deps; one library product
  Sources/CoreNetworking/
    NetworkClient.swift                ← protocol NetworkClient + HTTPMethod + NetworkError
    Reachability.swift                 ← protocol Reachability (isConnected + updates stream)
```

The App target provides:
- `NetworkClientImpl` — `URLSession` implementation, passed into each `<Domain>DataModule`
- `PathReachability` — `NWPathMonitor`-backed `Reachability`, exposed on `AppDependencies`
  for Features to inject later

No per-module adapter class is needed for either.

---

### `Core-Logging` — shared structured logging wrapper

`Core-Logging` wraps Apple's `os.Logger` and simultaneously writes logs to a rotating file on disk so QA testers can export and share logs without needing Xcode or a Mac.

```
Core-Logging/
  Package.swift                        ← zero external deps; one library product
  Sources/CoreLogging/
    AppLogger.swift                    ← AppLogger(subsystem:category:); writes to os.Logger + LogFileWriter
    LogFileWriter.swift                ← actor; creates per-session file, enforces 24h retention, respects enabled flag
    LogExporter.swift                  ← LogExporter.allLogFiles() → [URL]; used by App to share files
    LoggingConfiguration.swift         ← LoggingConfiguration(fileLoggingEnabled: Bool)
```

#### How it works

Every `AppLogger` call writes to two sinks simultaneously:
1. **`os.Logger`** — always active; visible in Console.app and Instruments during development
2. **`LogFileWriter` (actor)** — writes to a per-session file on disk; **disabled by default in production**

#### Per-session files

A new log file is created each time the app launches:

```
Documents/logs/
  2026-06-30T08-15-00Z.log   ← current session
  2026-06-29T14-22-10Z.log   ← previous session
```

On each launch `LogFileWriter` deletes any files older than 24 hours before creating the new session file.

```swift
// Format written to file:
// 2026-06-30T08:15:00Z [ERROR] DataSupport/Repository — Cache decode error — deleting corrupt file
```

#### Configuration — file logging off by default in production

The App configures logging once at startup in `AppDependencies`:

```swift
import CoreLogging

// Development / QA builds
LoggingConfiguration.configure(fileLoggingEnabled: true)

// Production builds
LoggingConfiguration.configure(fileLoggingEnabled: false)
```

`os.Logger` output is always active. File writing is skipped entirely when `fileLoggingEnabled` is `false` — no files are created, no disk I/O.

A typical setup using a build flag:

```swift
#if DEBUG
LoggingConfiguration.configure(fileLoggingEnabled: true)
#else
LoggingConfiguration.configure(fileLoggingEnabled: false)
#endif
```

#### Usage in any module

```swift
import CoreLogging

private let logger = AppLogger(subsystem: "DataSupport", category: "Repository")

logger.warning("API failed, serving cached data")
logger.error("Cache decode error — deleting corrupt file")
```

#### QA log export (App layer)

The App exposes a share button in a debug/settings screen that calls:

```swift
import CoreLogging

let urls = LogExporter.allLogFiles()   // returns all files in Documents/logs/
let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
present(activityVC, animated: true)
```

QA testers tap **Share Logs**, send the `.log` files via Slack/email, and you get logs for the current and previous sessions within the last 24 hours.

**Rules:**
- `os.Logger` is always active; file logging is **opt-in per build configuration**
- File logging is **off by default** — must be explicitly enabled for debug/QA builds
- Each app launch creates a new session file; files older than 24 hours are deleted automatically on launch
- Never use `print()` in module code; use `AppLogger` instead
- Log files must never contain sensitive user data (tokens, personal info) — log IDs and error types only

---

### `Core-Extensions` — shared Swift extensions and utilities

`Core-Extensions` is a Core-layer SPM package for common Swift extensions and utility helpers that are too generic to belong in any single feature or data module. Any module can import it.

```
Core-Extensions/
  Package.swift                        ← zero external deps; one library product
  Sources/CoreExtensions/
    String+Extensions.swift            ← trimming, capitalisation, regex helpers, localisation utilities
    Date+Extensions.swift              ← formatting, comparison, relative time helpers
    Collection+Extensions.swift        ← safe subscript, chunking, grouping helpers
    Optional+Extensions.swift          ← unwrapping helpers, default value operators
```

**Rules:**
- Extensions must be **purely functional** — no UIKit, SwiftUI, or side effects
- No business logic — if an extension is domain-specific it belongs in that module's `Models` file
- No third-party dependencies

---

## Feature module — internal folder structure

Every `Feature-<Domain>` package follows this layout:

```
Feature-<Domain>/
  Package.swift                         ← depends on Data-<Domain> + Core-DesignSystem
  Sources/Feature<Domain>/
    Feature<Domain>.swift               ← @_exported import Data<Domain>; static createScreen(…) → some View
    <Domain>AnalyticsTracking.swift     ← protocol; App target provides the concrete adapter
    UI/
      ViewModels/<Domain>ViewModel.swift ← @MainActor @Observable; state enum; injects repository protocol
      Views/<Domain>Screen.swift         ← @State var viewModel; .onAppear load; .errorAlert modifier
      Views/ErrorAlertModifier.swift     ← reusable .errorAlert(error:onRetry:onDismiss:) ViewModifier
    Resources/                          ← localizable strings, assets scoped to this feature
  Tests/Feature<Domain>Tests/
  Sources/<Domain>TestUtilities/        ← shared mocks (separate library product, not test-only)
```

---

## Dependency injection

### Data module DI — `<Domain>DataModule` (lazy var graph)

```swift
import CoreNetworking

public final class SupportDataModule {
    private let networkClient: NetworkClient

    public init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

    private lazy var api: SupportApi = SupportApiImpl(networkClient: networkClient)
    private lazy var localDataSource: SupportDataSource = JsonFileSupportDataSource()
    private lazy var bundledDataSource: BundledSupportDataSource = BundledSupportDataSource()
    private lazy var repository: SupportRepository = SupportRepositoryImpl(
        api: api, localDataSource: localDataSource, bundledDataSource: bundledDataSource
    )

    public func makeSupportRepository() -> SupportRepository { repository }
}
```

Prefer **lazy var** (instance-scoped) for stateful repositories so the same instance is reused.  
Use **static factory methods** only for stateless helpers (e.g. a standalone API or DataSource).

### Feature module DI — `<Domain>Module` (plain class)

```swift
public final class LoginModule {
    // ... dependencies stored as properties
    @MainActor public func makeLoginViewModel() -> LoginViewModel { ... }
}
```

### App DI — manual composition root

The App uses a manual composition root (no DI framework). Dependencies are instantiated once and held as properties on the root object (e.g. `AppDependencies` or `AppDelegate`).

```swift
final class AppDependencies {
    let networkClient: NetworkClient = NetworkClientImpl()

    lazy var supportModule = SupportDataModule(networkClient: networkClient)
    lazy var supportRepository: SupportRepository = supportModule.makeSupportRepository()
}
```

The App provides one shared `NetworkClient` implementation and passes it directly into each `<Domain>DataModule`. No per-module adapter class is needed — all Data modules accept the same `CoreNetworking.NetworkClient` protocol.

---

## ViewModel patterns

```swift
@MainActor @Observable
public final class SupportViewModel {
    public private(set) var state: SupportDataState = .loading
    private let repository: SupportRepository

    public init(repository: SupportRepository) {
        self.repository = repository
    }
}
```

Use `@Observable` for all ViewModels.

---

## State enum pattern

Every ViewModel uses a three-case state enum defined in the Data module's `Models` file:

```swift
public enum <Domain>DataState: Equatable {
    case loading
    case loaded(<Domain>Data)
    case error(String)

    public var isLoading: Bool { if case .loading = self { return true }; return false }
    public var data: <Domain>Data? { if case .loaded(let d) = self { return d }; return nil }
    public var errorMessage: String? { if case .error(let m) = self { return m }; return nil }
}
```

---

## Actor isolation rules

| Layer | Isolation | Rationale |
|-------|-----------|-----------|
| Repository with mutable in-memory cache | `actor` | Serialises concurrent reads/writes to `cachedVehicles` |
| Repository without shared mutable state | `final class` | Simpler; DataSource handles persistence |
| ViewModel | `@MainActor` | All published state must update on main thread |
| DataSource (disk I/O) | `final class` + `async` methods | File system calls are already thread-safe |

---

## Naming conventions

| Concept | Name |
|---------|------|
| Domain model | `<Domain>Data`, `<Domain>Section`, `<Domain>Item` |
| API DTO | `<Domain>Dto`, `<Domain>SectionDto` |
| API protocol | `<Domain>Api` |
| API implementation | `<Domain>ApiImpl` |
| Repository protocol | `<Domain>Repository` |
| Repository implementation | `<Domain>RepositoryImpl` |
| DataSource protocol | `<Domain>DataSource` |
| DataSource implementation | `JsonFile<Domain>DataSource`, `InMemory<Domain>DataSource` |
| Data module factory | `<Domain>DataModule` |
| Feature module factory | `<Domain>Module` |
| ViewModel | `<Domain>ViewModel` |
| Screen/View | `<Domain>Screen`, `<Domain>View` |
| Analytics protocol | `<Domain>AnalyticsTracking` |
| App-side DI container | `<Domain>Container` |

---

## Localisation

Localised strings are scoped to the module that owns the UI. The App target holds strings only when it genuinely owns the UI (e.g. app-level alerts, root navigation labels).

**Where strings live:**

| Scope | Location |
|-------|----------|
| Feature-specific UI | `Feature-<Domain>/Sources/Feature<Domain>/Resources/Localizable.xcstrings` |
| Shared DS components | `Core-DesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings` |
| App-level UI only | `App/Resources/Localizable.xcstrings` — use sparingly |

**Rules:**
- Prefer `.xcstrings` (String Catalog) over legacy `.strings` files
- Each Feature module accesses its own bundle via `String(localized:bundle:.module)`; never reference `Bundle.main` from inside a module
- Do not put feature strings in the App target to avoid coupling — if a string is used only in `Feature-Support`, it belongs in `Feature-Support`
- Exception: generic app-wide strings (e.g. "OK", "Cancel", "Error") that are reused across many modules may live in `Core-DesignSystem` resources to avoid duplication

---

## Key rules (summary)

1. **Cross-feature imports only for container features** — a container Feature (e.g. Home) may import sub-Features (e.g. Feature-Dashboard, Feature-Promotions) when the sub-feature is large enough to warrant its own module and is intended to be reused. Avoid cross-feature imports in all other cases; a plain Feature should never import a sibling Feature it doesn't compose.
2. **No App imports in modules** — modules never import `UIKit` app delegate, `AppSettings`, or any App-layer type
3. **Protocol boundaries at module edges** — pass protocols across package boundaries, never concrete types
4. **`NetworkClient` lives in `Core-Networking`** — all Data modules import the shared protocol; the App provides one concrete implementation via `BackendContainer`
5. **One composition root** — only the App target calls `<Domain>DataModule(networkClient:)` and `<Domain>Container`
6. **`@_exported import`** — Feature module re-exports its Data module so callers only need one import
