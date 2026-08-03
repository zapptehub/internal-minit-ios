# Testing

---

## Test target patterns

### Pattern A — Data module tests (no shared mocks needed)

Tests live in `Tests/<Domain>Tests/` inside the Data package. Mocks are `private` classes/enums defined at the **bottom of each test file**. No separate TestUtilities product is needed.

```
Data-<Domain>/
  Tests/
    Data<Domain>Tests/
      <Domain>ApiTests.swift          ← private MockNetworkClient inside
      <Domain>RepositoryTests.swift   ← private MockApi + MockDataSource inside
      <Domain>ModelMappingTests.swift
      <Domain>DataSourceTests.swift
```

### Pattern B — Feature module tests (mocks reused across tests and previews)

Add a **separate library product** `<Domain>TestUtilities` in the Feature package. This target is `public` so it can be imported in `#if DEBUG` preview code as well as test targets.

```swift
// Package.swift
products: [
    .library(name: "Feature-Login", targets: ["Feature-Login"]),
    .library(name: "Feature-LoginTestUtilities", targets: ["Feature-LoginTestUtilities"])
],
targets: [
    .target(name: "Feature-Login", ...),
    .target(name: "Feature-LoginTestUtilities", dependencies: ["Feature-Login"], path: "Sources/TestUtilities"),
    .testTarget(name: "Feature-LoginTests", dependencies: ["Feature-Login", "Feature-LoginTestUtilities"])
]
```

---

## Mock conventions

### Naming

```
Mock<ProtocolName>   e.g. MockSupportApi, MockNetworkClient, MockSupportRepository
```

### Scope

- `private` — mock used in a single test file (Data module tests)
- `public` — mock lives in a `TestUtilities` target and is reused elsewhere

### Spy flags

```swift
final class MockSupportApi: SupportApi {
    var fetchCalled = false
    var lastEndpoint: String?
    var shouldThrow = false
    var returnValue: SupportDto = SupportDto(culture: "sv", sections: [])

    func fetchSupportData() async throws -> SupportDto {
        fetchCalled = true
        if shouldThrow { throw MockError.testError }
        return returnValue
    }
}
```

### AsyncStream mocks

```swift
final class MockAuthorizationService: AuthorizationService {
    private var continuation: AsyncStream<AuthorizationState>.Continuation?

    var stream: AsyncStream<AuthorizationState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(.loggedOut(nil))
        }
    }

    func updateState(_ state: AuthorizationState) {
        continuation?.yield(state)
    }
}
```

---

## Test file structure

```swift
@MainActor                              // required when testing @MainActor ViewModels
final class SupportViewModelTests: XCTestCase {

    var sut: SupportViewModel!
    var mockRepository: MockSupportRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockSupportRepository()
        sut = SupportViewModel(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func testLoadSupportData_transitionsToLoaded_whenRepositorySucceeds() async {
        // Given
        mockRepository.returnValue = makeSupportData()

        // When
        sut.loadSupportData()
        await Task.yield()              // allow async task inside ViewModel to run

        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.sections.first)
    }
}
```

---

## Async test patterns

### Simple async call

```swift
func testFetchSupportData_callsCorrectEndpoint() async throws {
    let mock = MockNetworkClient()
    let sut = SupportApiImpl(networkClient: mock)

    _ = try await sut.fetchSupportData()

    XCTAssertEqual(mock.lastEndpoint, "v1/support")
    XCTAssertEqual(mock.lastMethod, .GET)
}
```

### Collecting AsyncThrowingStream emissions

```swift
func testRepository_emitsCacheThenFresh() async throws {
    // Given
    let cached = makeSupportData(culture: "cached")
    let fresh = makeSupportData(culture: "fresh")
    let sut = SupportRepositoryImpl(
        api: MockSupportApi(returnValue: makeSupportDto(from: fresh)),
        localDataSource: MockDataSource(initialData: cached),
        bundledDataSource: MockBundledDataSource()
    )

    // When
    var received: [SupportData] = []
    for try await data in sut.getSupportData() {
        received.append(data)
    }

    // Then
    XCTAssertEqual(received.count, 2)
    XCTAssertEqual(received[0].culture, "cached")
    XCTAssertEqual(received[1].culture, "fresh")
}
```

### Long-running stream with expectation

```swift
func testReachability_updatesWhenConnectionDrops() async {
    let expectation = expectation(description: "network update received")
    let mock = MockReachability(isConnected: true)

    Task {
        for await isConnected in mock.updates {
            if !isConnected {
                expectation.fulfill()
                break
            }
        }
    }

    mock.simulateConnectionChange(false)
    await fulfillment(of: [expectation], timeout: 2.0)
}
```

---

## Coverage targets per layer

### API layer
- Correct endpoint string and HTTP method are used
- Returned DTO is decoded and returned
- Network errors are propagated (not swallowed)

### DataSource layer
- `save` then `load` returns the same data (round-trip)
- `load` returns `nil` when no file exists
- Corrupt cache file is deleted and `nil` is returned gracefully
- `clear` makes subsequent `load` return `nil`

### Repository layer
- Cache-first: cached data is emitted **before** network data
- Bundled fallback is used when cache is empty
- API failure does **not** throw when initial data was emitted (graceful finish)
- API success saves data to `localDataSource`
- `yieldIfChanged` prevents duplicate emissions of equal data
- Both cache and API fail → stream throws error

### ViewModel layer
- Initial state is `.loading`
- Successful load transitions to `.loaded`
- Error from repository transitions to `.error`
- `clearError()` triggers a reload (state returns to `.loading`)
- Analytics methods are called at correct trigger points

---

## Rules

- Never test `private` methods — test only through the public interface
- `@testable import` is permitted for internal access when necessary
- Each test asserts **one** logical outcome; split into separate `func test…` if multiple outcomes need checking
- Use `makeSomeModel()` factory helpers at the bottom of the test file instead of repeating fixture construction
- Data module mocks stay `private` inside test files; only move to `TestUtilities` when genuinely shared
