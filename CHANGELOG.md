# Changelog

All notable changes to this project are documented in this file following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).

## [3.0.0] - 2026-11-11

### Added
- **Multi-Workspace Profiles & Strict Isolation:** Support for isolated `Personal`, `Business`, `Trip`, `Project`, and `SavingsPool` workspaces (`Workspace`, `WorkspaceType`), per-workspace currency symbols, reports partitions, bill reminder notification channels (`budgo_ws_<id>_v1`), and selective/single-workspace data clearing.
- **Custody Accounts, Atomic Self-Transfers & Savings Vaults:** Signed net equity accounting (`Cash`, `Bank Account`, `UPI`, `Credit Card` stored in 64-bit integer paise/cents), cross-account and cross-workspace sweep transfers (`AtomicWriter` + `TransferJournalEntry` reversals), and goal-based `SavingsVault` allocations.
- **Safe-to-Spend Daily Allowance & Pay-Yourself-First:** Math-backed daily burn rate engine with an interactive step-by-step derivation sheet, draft-to-confirmed salary inflows, and 1-tap credit card settlement triage.
- **Zero-Black-Screen Boot & Fault Tolerance:** Native Android (`launch_background.xml`) and iOS (`LaunchScreen.storyboard`) surface alignment, `<16ms` `SplashScreen` with Material 3 Expressive wavy progress indicator (`BudgoWavyProgressIndicator`), 7-stage non-blocking `AppInitializer.boot()`, and graceful `BudgoStartupErrorView` recovery.
- **Publication-Grade CSV & PDF Export Isolates:** Streaming `IOSink` CSV exports with UTF-8 BOM + CSV formula-injection neutralization, bundled offline `Roboto` fonts for full Unicode currency symbols (`₹`, `€`, `£`, `¥`, `$`), top-center masthead + logo PDF layout, cumulative vector `pw.Chart` trend graph with legend, and selectable workspace scope.
- **Unified Design System (`BudgoUI`) & Input Governance:** Borderless 3-tier layered action dialog (`BudgoActionDialog` + `BudgoLayeredActionLayout`), global `AppInputLimits` & `BudgoCharacterCounter` (e.g., 20-char no-space workspace names), contextual guidance placeholders, and top-layer `Overlay` toast notifications (`BudgoToastBanner`).
- **Centralized Branding & Cryptographic Integrity Vault:** Single-source `tool/brand_manifest.json` + `tool/sync_brand.dart` generator, pure-Dart FIPS 180-4 SHA-256 + rotating XOR byte masking (`BrandIntegrity` / `AppBrand`), unified `AppBrandLogo`, and refactored `About & Legal` screen (`LegalDocumentSheet`).
- **Automated Test Suite:** Expanded coverage to **127 tests across 29 test files** covering core, design, models, providers, services (including 24,000-row OLAP/export stress tests), and widgets.

### Changed
- Reorganized architecture cleanly into `lib/core/*`, `lib/design/*`, `lib/providers/`, `lib/repositories/`, `lib/services/`, and `lib/widgets/sheets/`.
- Rebuilt `README.md` with system architecture diagrams, Hive schema registry, brand sync workflow, verification matrix, truthful missing-feature roadmap, and legal notice.

### Fixed
- Resolved Hive lazy-initialization hot-restart crash (`Box not found` in `DataLifecycleService` and `HiveAccountRepository`).
- Resolved workspace leakages in Reports OLAP views, Data Lifecycle deletion, and OS reminder notification scheduling.

---

## [2.0.0] - 2026-06-07

### Added
- Refined Home, Activity, Settings, and Reports visual experience (Pie, Line, and Calendar Heatmap views).
- Proprietary LICENSE and Android R8 release configuration updates.

---

## [1.0.0] - 2026-06-07

### Added
- Initial offline Flutter expense, income, budget, wishlist, and reminder tracker backed by Hive.

