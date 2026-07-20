# iOS Skills

Reusable, project-agnostic reference files for iOS development with SwiftUI + Swift Concurrency + SPM modular architecture.

**Stack**: SwiftUI · Swift Concurrency (`async/await`, `actor`, `AsyncThrowingStream`) · Swift Package Manager (SPM) · Factory DI · Sentry error tracking

---

## Files

| File | Load when you need to… |
|------|------------------------|
| [`01-architecture.md`](01-architecture.md) | Understand module boundaries, folder structures, DI wiring, or naming conventions |
| [`02-testing.md`](02-testing.md) | Write unit tests, create mocks, set up test targets in SPM |
| [`03-error-handling.md`](03-error-handling.md) | Handle errors — when to show UI alerts vs send to Sentry, environment error propagation |
| [`04-caching.md`](04-caching.md) | Implement cache-first data loading, `AsyncThrowingStream` streaming, offline fallback |
| [`05-design-system.md`](05-design-system.md) | Use color tokens, spacing constants, typography, existing components, Figma MCP workflow |
| [`06-new-feature-template.md`](06-new-feature-template.md) | Scaffold a complete new feature from scratch (Data module → Feature module → App wiring) |

---

## Core principles

- **DRY** — repeated logic or UI patterns get extracted; each concept lives in exactly one place
- **Single Responsibility** — each type (ViewModel, Repository, DataSource, Component) has one job
- **Protocol-first** — depend on protocols, not concrete types; swap implementations freely (production, mock, demo)
- **Cache-first UX** — views render immediately from cache; network updates arrive in the background
- **Errors are never silent** — every `catch` either reports to Sentry, shows the user a message, or has an explicit comment explaining why it is intentionally ignored
