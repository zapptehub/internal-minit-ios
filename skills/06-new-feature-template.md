# New Feature Template

Step-by-step recipe for adding a complete new feature, from Data module through Feature module to App wiring. Replace `<Domain>` with your feature name (e.g. `Support`, `Claims`, `Warranty`).

Reference implementations: `Data-Support` + `Feature-Support` are the canonical examples to follow.

---

## Step 1 — Create `Data-<Domain>` SPM package

### 1.1 `Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Data-<Domain>",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Data<Domain>", targets: ["Data<Domain>"])
    ],
    dependencies: [
        .package(path: "../../Core/Core-Networking")
    ],
    targets: [
        .target(
            name: "Data<Domain>",
            dependencies: [
                .product(name: "CoreNetworking", package: "Core-Networking")
            ],
            path: "Sources/Data<Domain>",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "Data<Domain>Tests",
            dependencies: ["Data<Domain>"]
        )
    ]
)
```

### 1.2 `API/<Domain>Api.swift`

```swift
import CoreNetworking

public protocol <Domain>Api {
    func fetch<Domain>Data() async throws -> <Domain>Dto
}

public final class <Domain>ApiImpl: <Domain>Api {
    private let networkClient: NetworkClient
    public init(networkClient: NetworkClient) { self.networkClient = networkClient }

    public func fetch<Domain>Data() async throws -> <Domain>Dto {
        return try await networkClient.request("v1/<domain>", method: .GET)
    }
}
```

### 1.3 `Models/<Domain>Models.swift`

```swift
// Domain model
public struct <Domain>Data: Codable, Equatable {
    public let id: String
    // ... fields
}

// State enum — always these three cases
public enum <Domain>DataState: Equatable {
    case loading
    case loaded(<Domain>Data)
    case error(String)

    public var isLoading: Bool { if case .loading = self { return true }; return false }
    public var data: <Domain>Data? { if case .loaded(let d) = self { return d }; return nil }
    public var errorMessage: String? { if case .error(let m) = self { return m }; return nil }
}

// DTO (matches backend JSON)
public struct <Domain>Dto: Codable, Sendable {
    public let id: String
    // ... fields
}

// DTO → model mapping
extension <Domain>Dto {
    public func toModel() -> <Domain>Data {
        <Domain>Data(id: id /*, ... */)
    }
}
```

### 1.4 `Data/<Domain>DataSource.swift`

```swift
public protocol <Domain>DataSource {
    func load() async throws -> <Domain>Data?
    func save(_ data: <Domain>Data) async throws
    func clear() async throws
}

public final class JsonFile<Domain>DataSource: <Domain>DataSource {
    private var fileURL: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("<domain>_cache.json")
    }

    public init() {}

    public func load() async throws -> <Domain>Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try JSONDecoder().decode(<Domain>Data.self, from: Data(contentsOf: fileURL))
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    public func save(_ data: <Domain>Data) async throws {
        let json = try JSONEncoder().encode(data)
        try json.write(to: fileURL, options: .atomic)
    }

    public func clear() async throws {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// Optional: open class for bundled default data
open class Bundled<Domain>DataSource {
    public init() {}
    open func loadDefault() async throws -> <Domain>Data {
        guard let url = Bundle.module.url(forResource: "<domain>_default", withExtension: "json") else {
            throw NSError(domain: "Bundled<Domain>DataSource", code: 404)
        }
        return try JSONDecoder().decode(<Domain>Data.self, from: Data(contentsOf: url))
    }
}
```

### 1.5 `Data/<Domain>Repository.swift`

```swift
public protocol <Domain>Repository {
    func get<Domain>Data() -> AsyncThrowingStream<<Domain>Data, Error>
}

public final class <Domain>RepositoryImpl: <Domain>Repository {
    private let api: <Domain>Api
    private let localDataSource: <Domain>DataSource
    private let bundledDataSource: Bundled<Domain>DataSource

    public init(api: <Domain>Api, localDataSource: <Domain>DataSource, bundledDataSource: Bundled<Domain>DataSource) {
        self.api = api
        self.localDataSource = localDataSource
        self.bundledDataSource = bundledDataSource
    }

    public func get<Domain>Data() -> AsyncThrowingStream<<Domain>Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var lastEmitted: <Domain>Data?
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
                        let fresh = try await api.fetch<Domain>Data().toModel()
                        try await localDataSource.save(fresh)
                        yieldIfChanged(fresh, lastEmitted: &lastEmitted, continuation: continuation)
                        continuation.finish()
                    } catch {
                        continuation.finish()   // graceful — user already sees cached data
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func yieldIfChanged(
        _ data: <Domain>Data,
        lastEmitted: inout <Domain>Data?,
        continuation: AsyncThrowingStream<<Domain>Data, Error>.Continuation
    ) {
        guard lastEmitted != data else { return }
        lastEmitted = data
        continuation.yield(data)
    }
}
```

### 1.6 `DI/<Domain>DataModule.swift`

```swift
import CoreNetworking

public final class <Domain>DataModule {
    private let networkClient: NetworkClient
    public init(networkClient: NetworkClient) { self.networkClient = networkClient }

    private lazy var api: <Domain>Api = <Domain>ApiImpl(networkClient: networkClient)
    private lazy var localDataSource: <Domain>DataSource = JsonFile<Domain>DataSource()
    private lazy var bundledDataSource: Bundled<Domain>DataSource = Bundled<Domain>DataSource()
    private lazy var repository: <Domain>Repository = <Domain>RepositoryImpl(
        api: api, localDataSource: localDataSource, bundledDataSource: bundledDataSource
    )

    public func make<Domain>Repository() -> <Domain>Repository { repository }
}
```

### 1.7 Tests

Write these three test files in `Tests/Data<Domain>Tests/`:

| File | Tests |
|------|-------|
| `<Domain>ApiTests.swift` | Correct endpoint, correct method, error propagation |
| `<Domain>RepositoryTests.swift` | Cache-first order, API failure graceful finish, deduplication, bundled fallback, save on success |
| `<Domain>ModelMappingTests.swift` | `toModel()` correctness for all fields |

---

## Step 2 — Create `Feature-<Domain>` SPM package

### 2.1 `Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-<Domain>",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Feature<Domain>", targets: ["Feature<Domain>"])
        // Add TestUtilities product if mocks are needed in previews:
        // .library(name: "Feature<Domain>TestUtilities", targets: ["Feature<Domain>TestUtilities"])
    ],
    dependencies: [
        .package(path: "../../Core/Core-DesignSystem"),
        .package(path: "../../Data/Data-<Domain>")
    ],
    targets: [
        .target(
            name: "Feature<Domain>",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "Data<Domain>", package: "Data-<Domain>")
            ],
            path: "Sources/Feature<Domain>",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "Feature<Domain>Tests", dependencies: ["Feature<Domain>"])
    ]
)
```

### 2.2 `Feature<Domain>.swift`

```swift
import Foundation
import SwiftUI
import Data<Domain>

@_exported import Data<Domain>    // callers only need: import Feature<Domain>

public struct Feature<Domain> {
    @MainActor
    public static func createScreen(
        repository: <Domain>Repository,
        analytics: <Domain>AnalyticsTracking? = nil
    ) -> some View {
        let viewModel = <Domain>ViewModel(repository: repository)
        return <Domain>Screen(viewModel: viewModel, analytics: analytics)
    }
}
```

### 2.3 `<Domain>AnalyticsTracking.swift`

```swift
public protocol <Domain>AnalyticsTracking {
    func trackScreenOpened()
    func trackItemTapped(analyticsKey: String)
    // add events specific to this feature
}
```

### 2.4 `UI/ViewModels/<Domain>ViewModel.swift`

```swift
import Foundation
import Observation
import Data<Domain>

@MainActor @Observable
public final class <Domain>ViewModel {
    public private(set) var state: <Domain>DataState = .loading

    private let repository: <Domain>Repository

    public init(repository: <Domain>Repository) {
        self.repository = repository
    }

    public func load<Domain>Data() {
        state = .loading
        Task {
            do {
                for try await data in repository.get<Domain>Data() {
                    state = .loaded(data)
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    public var isLoading: Bool { state.isLoading }
    public var error: String? { state.errorMessage }

    public func clearError() {
        if case .error = state { load<Domain>Data() }
    }
}
```

### 2.5 `UI/Views/<Domain>Screen.swift`

```swift
import SwiftUI
import DesignSystem

public struct <Domain>Screen: View {
    @State private var viewModel: <Domain>ViewModel
    let analytics: <Domain>AnalyticsTracking?

    public init(viewModel: <Domain>ViewModel, analytics: <Domain>AnalyticsTracking? = nil) {
        _viewModel = State(wrappedValue: viewModel)
        self.analytics = analytics
    }

    public var body: some View {
        ZStack {
            TColor.Background.Layer.level0.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView()
            } else {
                contentView
            }
        }
        .navigationTitle(String(localized: "<Domain>", bundle: .module))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.load<Domain>Data()
            analytics?.trackScreenOpened()
        }
        .errorAlert(
            error: viewModel.error,
            onRetry: { viewModel.load<Domain>Data() },
            onDismiss: { viewModel.clearError() }
        )
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TConstant.large.value) {
                // build UI using TiaCard, TColor, TConstant, .typography()
            }
            .defaultSidePadding()
            .padding(.top, TConstant.large.value)
        }
    }
}
```

### 2.6 `UI/Views/ErrorAlertModifier.swift`

```swift
import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    let error: String?
    let onRetry: () -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "Something went wrong", bundle: .module),
            isPresented: Binding(get: { error != nil }, set: { if !$0 { onDismiss() } })
        ) {
            Button(String(localized: "Try Again", bundle: .module)) { onRetry() }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) { onDismiss() }
        } message: {
            if let error { Text(error) }
        }
    }
}

extension View {
    func errorAlert(error: String?, onRetry: @escaping () -> Void, onDismiss: @escaping () -> Void) -> some View {
        modifier(ErrorAlertModifier(error: error, onRetry: onRetry, onDismiss: onDismiss))
    }
}
```

---

## Step 3 — App wiring

### 3.1 `App/AppDependencies.swift`

Add the new module and repository to the app's manual composition root:

```swift
extension AppDependencies {
    lazy var <domain>Module = <Domain>DataModule(networkClient: networkClient)
    lazy var <domain>Repository: <Domain>Repository = <domain>Module.make<Domain>Repository()
}
```

### 3.2 Analytics adapter

```swift
final class <Domain>AnalyticsAdapter: <Domain>AnalyticsTracking {
    func trackScreenOpened() {
        Tracker.track(event: .<domain>(step: .screen_opened))
    }
    func trackItemTapped(analyticsKey: String) {
        Tracker.track(event: .<domain>(step: .item_tapped(analyticsKey)))
    }
}
```

### 3.3 Navigation entry point

```swift
// In App/UI/Navigation/ or the relevant tab/root view
Feature<Domain>.createScreen(
    repository: appDependencies.<domain>Repository,
    analytics: <Domain>AnalyticsAdapter()
)
```

---

## Checklist

### Data module
- [ ] `Package.swift` — depends on Core-Networking
- [ ] `<Domain>Api.swift` — protocol + Impl (import CoreNetworking)
- [ ] `<Domain>DataSource.swift` — protocol + JsonFile impl + optional BundledDataSource
- [ ] `<Domain>Repository.swift` — protocol + Impl with cache-first stream
- [ ] `<Domain>Models.swift` — domain structs + state enum + DTOs + toModel()
- [ ] `<Domain>DataModule.swift` — lazy var graph + make factory method
- [ ] Default JSON in `Resources/` (if using bundled fallback)
- [ ] `<Domain>ApiTests.swift`
- [ ] `<Domain>RepositoryTests.swift`
- [ ] `<Domain>ModelMappingTests.swift`

### Feature module
- [ ] `Package.swift` — depends on Data-<Domain> + Core-DesignSystem
- [ ] `Feature<Domain>.swift` — @_exported import + createScreen factory
- [ ] `<Domain>AnalyticsTracking.swift` — protocol
- [ ] `<Domain>ViewModel.swift` — @MainActor @Observable, state, load, clearError
- [ ] `<Domain>Screen.swift` — @State viewModel, onAppear, errorAlert
- [ ] `ErrorAlertModifier.swift`
- [ ] Figma consulted before building any UI
- [ ] All colors use `TColor.*`, spacing uses `TConstant.*`, text uses `.typography()`

### App wiring
- [ ] `AppDependencies` extended with `<domain>Module` and `<domain>Repository` lazy vars
- [ ] Analytics adapter conforming to `<Domain>AnalyticsTracking`
- [ ] Navigation entry point added
