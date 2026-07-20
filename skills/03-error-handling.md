# Error Handling

---

## The three rules

1. **Foreground errors → show to user** — if the user triggered an action and it fails, surface an alert
2. **Background errors → error reporter only** — silent background refreshes that fail should be captured by the error reporter (console log early in the project, Sentry once integrated) but never interrupt the user
3. **Every `catch` is accounted for** — every `catch` block must either show UI, call the error reporter, or carry an explicit comment `// intentional no-op — <reason>`
4. **All errors are logged** — every caught error is logged via `AppLogger` (`Core-Logging`) regardless of whether it is also reported to the error reporter

---

## Where errors are handled

| Layer | Responsibility |
|-------|---------------|
| Repository | Catches network/decode errors; applies fallback logic (return cache); re-throws only when no data is available at all |
| ViewModel | Catches errors from repository calls; sets `state = .error(message)`; calls error reporter |
| View | Reads `viewModel.error`; renders alert; provides Retry / Dismiss actions |
| App root | Environment `\.appError` key — catches errors bubbled up from deep in the tree; shows global alert + calls error reporter |

---

## ViewModel error pattern

```swift
@MainActor @Observable
public final class SupportViewModel {
    public private(set) var state: SupportDataState = .loading

    public func loadSupportData() {
        state = .loading
        Task {
            do {
                for try await data in repository.getSupportData() {
                    state = .loaded(data)
                }
            } catch {
                state = .error(error.localizedDescription)
                logger.error(error.localizedDescription)
                errorReporter.report(error, context: nil)
            }
        }
    }

    public func clearError() {
        if case .error = state { loadSupportData() }
    }
}
```

---

## View error surface — `.errorAlert` modifier

Every screen that loads data attaches this modifier:

```swift
.errorAlert(
    error: viewModel.error,
    onRetry: { viewModel.loadSupportData() },
    onDismiss: { viewModel.clearError() }
)
```

The modifier implementation (lives in `UI/Views/ErrorAlertModifier.swift` inside the Feature module):

```swift
struct ErrorAlertModifier: ViewModifier {
    let error: String?
    let onRetry: () -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Something went wrong",
            isPresented: Binding(get: { error != nil }, set: { if !$0 { onDismiss() } })
        ) {
            Button("Try Again") { onRetry() }
            Button("Cancel", role: .cancel) { onDismiss() }
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

## App-level environment error action

For errors that originate deep in the view hierarchy and should bubble up to a global alert:

```swift
// App root wires the environment key
.environment(\.appError, AppErrorAction(handler: { message in
    MainActor.assumeIsolated {
        self.errorMessage = message      // @State on MainApp
    }
}))
.alert(item: $errorMessage) { msg in
    Alert(title: Text(msg.title), message: Text(msg.message))
}

// Any child view triggers it
@Environment(\.appError) private var errorAction

errorAction.handler(AppErrorMessage(title: "Login Failed", message: "Something went wrong."))
```

Use the environment action when:
- the error is critical enough to always interrupt the user
- the view is too deep in the hierarchy to own its own `@State var errorMessage`

---

## Error reporter

Error reporting is abstracted behind an `ErrorReporter` protocol so the call sites are stable regardless of whether Sentry is integrated yet.

```swift
public protocol ErrorReporter {
    func report(_ error: Error, context: [String: Any]?)
}
```

The App target provides the concrete implementation and injects it at startup. Two implementations are expected over the project lifetime:

### Phase 1 — console only (before Sentry is added)

```swift
final class ConsoleErrorReporter: ErrorReporter {
    func report(_ error: Error, context: [String: Any]?) {
        // Phase 1: no-op — AppLogger in Core-Logging already logs the error at call site
    }
}
```

### Phase 2 — Sentry (once integrated)

Sentry is initialised once in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`:

```swift
SentrySDK.start { options in
    options.dsn = "<your-dsn>"
    options.environment = SentryEnvironment.current().environmentString
    options.tracesSampleRate = 1.0
    options.attachScreenshot = true
    options.attachViewHierarchy = true
    options.enableCaptureFailedRequests = true
}
```

```swift
final class SentryErrorReporter: ErrorReporter {
    func report(_ error: Error, context: [String: Any]?) {
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: error.localizedDescription)
        event.extra = context
        SentrySDK.capture(event: event)
    }
}
```

Swapping implementations requires changing one line in `AppDependencies` — no call sites change.

### Usage at call sites

```swift
import CoreLogging

private let logger = AppLogger(subsystem: "DataSupport", category: "Repository")

// Log first, then report — always both, never just one
logger.error(error.localizedDescription)
errorReporter.report(error, context: ["endpoint": "v1/support"])
```

---

## Error type hierarchy — order of `catch` clauses

```swift
do {
    try await authorizationService.login(args: args)
} catch let error as LoginError {
    // Most specific — typed domain error
    handleLoginError(error)
} catch let urlError as URLError {
    // Network-level error
    handleNetworkError(urlError)
} catch {
    // Generic fallback
    handleGenericError(error)
}
```

Always catch typed errors before `URLError` before generic `Error`.

---

## Background vs foreground decision tree

```
Error occurs
│
├── Was it triggered by a direct user action (button tap, pull-to-refresh)?
│    └── YES → show .errorAlert + log via AppLogger + call errorReporter.report()
│
└── NO — background refresh / silent update
     ├── Was initial data already shown to the user?
     │    └── YES → finish stream gracefully (no throw); log via AppLogger + call errorReporter.report() silently
     └── NO — no data at all available
          └── throw error → ViewModel catches → state = .error → show .errorAlert
```

---

## Anti-patterns to avoid

```swift
// ❌ Silently swallowed
catch { }

// ❌ Generic message without tracking
catch { state = .error("Error") }

// ❌ Alert on background refresh
Task {
    try await backgroundRefresh()   // user didn't ask for this
    // ...
} catch { showAlert = true }        // don't do this

// ✅ Correct background handling
} catch {
    logger.error(error.localizedDescription)
    errorReporter.report(error, context: nil)
    continuation.finish()           // graceful, user sees stale cached data
}
```
