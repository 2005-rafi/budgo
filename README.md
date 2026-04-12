# Budgo - Expense Management App

This document is a complete QA-style implementation analysis of the current Flutter project, based on the source code in `lib/` and dependency configuration in `pubspec.yaml`.

## 1) Product Overview

Budgo is an offline-first personal finance tracker focused on:

- Day-to-day expense tracking
- Future purchase planning (wishlist-style)
- Income entry with confirmation workflow
- Budget control (overall, weekly, monthly)
- Reports with charts and export (CSV/PDF)

The app uses local persistence via Hive and state management via Provider.

## 2) Architecture

### 2.1 Architectural Style

The app follows a pragmatic layered style:

- Presentation layer:
	- Screens and UI widgets in `lib/screens/` and `lib/widgets/`
- State layer:
	- ChangeNotifier providers in `lib/provider/`
- Data layer:
	- Hive models and boxes in `lib/models/` and `lib/provider/finance_boxes.dart`
- Utility/service layer:
	- Reporting export service in `lib/services/report_export_service.dart`
	- Theme system in `lib/themes/`

This is not strict Clean Architecture (no repository abstraction layer between provider and Hive), but it is organized and maintainable for an MVP-to-growth application.

### 2.2 Bootstrapping and Dependency Wiring

In `main.dart`, startup does the following:

1. Initializes Flutter bindings.
2. Initializes Hive with application documents directory.
3. Registers Hive adapters for:
	 - Expense
	 - Income
	 - FutureExpense
	 - Budget
4. Opens four Hive boxes:
	 - expenses
	 - incomes
	 - future_expenses
	 - budgets
5. Creates provider graph via `MultiProvider`.

Provider graph includes direct and proxy providers:

- `ThemeProvider`
- `ExpensesProvider`
- `IncomeProvider`
- `FutureExpensesProvider`
- `BudgetProvider` (proxy-injected with `IncomeProvider`)
- `FutureExpensesProvider` again via proxy to inject `ExpensesProvider`

QA note: `FutureExpensesProvider` is registered twice (direct provider plus proxy provider). The proxy instance is the one that should be consumed; this duplication is functional but unnecessary and can cause confusion for maintainers.

## 3) Data Model and Persistence Design

### 3.1 Hive Entities

#### Expense (`typeId: 0`)

- `productName`
- `amount`
- `category`
- `date`

#### Income (`typeId: 1`)

- `id`
- `source`
- `amount`
- `date`
- `description` (optional)
- `isConfirmed`

#### FutureExpense (`typeId: 2`)

- `id`
- `title`
- `estimatedCost` (optional)
- `priority` (1..3)
- `dueDate` (optional)
- `isPurchased`
- `category`
- `notes` (optional)
- `linkedExpenseKey` (links to real Expense box key when converted)
- `purchasedAmount` (optional)
- `purchasedAt` (optional)

#### Budget (`typeId: 3`)

- `id`
- `limit`
- `period` (overall / weekly / monthly)
- `startDate`
- `endDate`
- `isActive`
- `warningThreshold`

### 3.2 Box Registry

Centralized names in `FinanceBoxes`:

- expenses
- incomes
- future_expenses
- budgets
- active budget key: `active_budget`

## 4) Data Flow (End-to-End)

### 4.1 Expense Flow

1. User submits form in Add Expense screen.
2. Screen validates input and creates `Expense` model.
3. Calls `ExpensesProvider.addExpense()`.
4. Provider writes to Hive expenses box.
5. Box watcher triggers provider reload.
6. UI updates through Consumer/Provider listeners.

Additional path:

- Home and Expense List screens also use `ValueListenableBuilder` directly on Hive box for live rendering.

QA observation: app mixes provider-driven state with direct Hive listenables in different screens. This works, but introduces two data access patterns that can diverge in future refactors.

### 4.2 Income Flow

1. User creates income entry (saved as draft: `isConfirmed = false`).
2. User may confirm immediately or later.
3. On confirm, `IncomeProvider.confirmIncome()` updates model in Hive.
4. `BudgetProvider` reads confirmed income contribution through proxy-attached `IncomeProvider`.
5. Budget figures include base budget + confirmed income.

### 4.3 Future Expense Conversion Flow

1. User adds planned item to future expenses.
2. On purchase action, app asks for actual amount.
3. Provider creates real `Expense` in expenses box.
4. Future item is marked purchased and stores `linkedExpenseKey`.
5. Undo purchase deletes linked expense and resets future item state.

This conversion logic is a strong design decision that keeps wishlist and actual spending synchronized.

### 4.4 Budget Flow

1. User sets budget period (overall/weekly/monthly) and amount.
2. `BudgetProvider` calculates active range and stores active budget in Hive using single key.
3. Spending in active period is computed from `ExpensesProvider.totalBetween()`.
4. Usage ratio drives near-limit and over-limit signals.
5. UI progress bars and warning messages react accordingly.

### 4.5 Reports Flow

1. User selects preset/custom date range.
2. Screen filters expenses for range.
3. Computes KPIs and chart datasets.
4. Export options:
	 - CSV file generated in app documents directory and shared via `share_plus`
	 - PDF bytes generated via `pdf` package and shared via `printing`

## 5) System Design

### 5.1 Module Responsibilities

- `main.dart`:
	- Runtime initialization, adapter registration, box opening, provider tree
- `models/`:
	- Typed persistent domain objects
- `provider/`:
	- State mutation, reactive loading, computed finance metrics
- `screens/`:
	- User workflows and presentation logic
- `services/report_export_service.dart`:
	- Reporting output generation (CSV/PDF)
- `themes/`:
	- Material color system and text theme support
- `widgets/app_drawer.dart`:
	- Global navigation drawer and route switching

### 5.2 Navigation Design

Named routes are centralized in `navigation/app_routes.dart`.
App uses route reset navigation (`pushNamedAndRemoveUntil`) for drawer actions and back guard behavior in multiple screens (`PopScope`) to keep flow anchored to Home.

### 5.3 Reactivity Strategy

- Providers subscribe to Hive box `watch()` and call `load()`.
- Some screens subscribe directly with `ValueListenableBuilder`.

This guarantees near-instant UI updates on local data changes.

## 6) Core Functionalities Implemented

### 6.1 Expense Tracking

- Add expense with:
	- Product name
	- Amount
	- Category (including custom category via "Other")
	- Date picker
- Edit/delete expense from Home list dialog/menu
- Full expense list view with category-wise pie chart and total spent

### 6.2 Income Management

- Add income entries with source/date/amount/description
- Confirmation-based inclusion model
- Confirm or delete entries
- Summary metrics:
	- Confirmed total
	- All entries total
	- Pending count

### 6.3 Future Expenses (Planning)

- Add planned purchases with category/priority/optional due date
- Separate planned vs purchased sections
- Convert planned item to actual expense with actual paid amount
- Undo purchased state and reverse linked expense

### 6.4 Budget Management

- Supports three budget modes:
	- Overall
	- Weekly
	- Monthly
- Active budget card:
	- Limit, spent, remaining
	- Progress bar
	- Near-limit and over-limit alerts
- Clear budget action

### 6.5 Reports and Analytics

- Date range presets:
	- This week
	- This month
	- Last 30 days
	- Custom range picker
- KPI cards:
	- Total spent
	- Transaction count
	- Average expense
- Insights:
	- Top category
	- Spending trend bar chart
	- Category split pie chart
	- Top expenses list
- Export:
	- CSV (complete rows)
	- PDF (summary + up to 200 rows)

### 6.6 App Experience Utilities

- Splash screen with fade animation and branding
- Drawer-based global navigation
- Theme mode persistence via SharedPreferences
- Exit confirmation from home screen
- Reset expenses action in settings

## 7) Tech Stack and Usage

From `pubspec.yaml`:

### 7.1 Framework and Language

- Flutter SDK
- Dart SDK `^3.8.1`

### 7.2 State Management

- `provider`: application state, reactive UI binding, dependency injection with proxy providers

### 7.3 Local Database

- `hive`: NoSQL local storage
- `hive_flutter`: Flutter integration and listenables
- `hive_generator` + `build_runner` (dev): type adapter code generation

### 7.4 UI and Visuals

- Material 3 theme structure
- `fl_chart`: pie and bar charts
- `auto_size_text`: adaptive summary text scaling
- `google_fonts`: dynamic text theme creation utility

### 7.5 Formatting and Localization

- `intl`: currency/date formatting and date labels

### 7.6 File and Sharing Utilities

- `path_provider`: file location paths
- `csv`: CSV string generation
- `pdf`: PDF document generation
- `printing`: PDF share/print bridge
- `share_plus`: file sharing for exports

### 7.7 Preferences and Device Integration

- `shared_preferences`: persisted theme mode
- `flutter_launcher_icons`: app icon generation

## 8) Screens and Responsibilities

- `SplashScreen`:
	- Animated startup branding
	- Delayed route transition to Home

- `HomeScreen`:
	- Summary cards (budget/spent/remaining)
	- Budget usage progress bar
	- Recent expenses list with edit/delete
	- Primary add-expense entry point

- `AddExpenseScreen`:
	- Expense creation form
	- Validations and category/date input

- `ExpenseListScreen`:
	- Historical expense feed
	- Pie chart category distribution
	- Total spent overview

- `IncomeScreen`:
	- Income history and state (pending/confirmed)
	- Add/confirm/delete workflows

- `FutureExpensesScreen`:
	- Wishlist planning list
	- Purchase conversion to real expense
	- Purchased/planned sectioning and priority indicators

- `BudgetScreen`:
	- Budget setup and reset
	- Active budget KPIs and progress/warnings

- `ReportsScreen`:
	- Date-range analytics
	- Bar/pie charts and top-spend insights
	- CSV/PDF export actions

- `SettingsScreen`:
	- Data destructive action (reset all expenses)
	- Placeholder/commented area indicates theme settings intent

## 9) Other Utilities Implemented

- `AppDrawer`:
	- Current-route highlighting
	- Stack-reset navigation for predictable app flow

- `ReportExportService`:
	- Safe file naming
	- Structured CSV export
	- Multi-page PDF export with summary and table

- Theme utility (`themes/util.dart`):
	- Supports customizable text themes via Google Fonts (currently utility-level, not deeply integrated across all runtime theme generation)

## 10) MVP Explanation (What Has Been Built)

### 10.1 MVP Scope Achieved

The project has evolved beyond a basic expense logger and now qualifies as a functional personal finance MVP with planning + reporting:

- Core expense capture and history
- Budget visibility and alerts
- Income tracking with confirmation gate
- Future purchase planning linked to real expenses
- Time-based analytics and export capabilities

### 10.2 User Value Delivered by MVP

- Daily control: add/edit/delete expenses quickly
- Financial awareness: summary, category insights, trends
- Planning discipline: future purchases and budget limits
- Portability of records: CSV and PDF sharing

### 10.3 QA Assessment of MVP Quality

Strengths:

- Solid local-first reliability
- Meaningful provider architecture with reactive updates
- Good breadth of finance workflows for first release
- Useful reporting/export integration

Improvement opportunities:

- Standardize data access (provider-only or clearly-defined direct Hive usage)
- Remove duplicate provider registration for `FutureExpensesProvider`
- Settings currently resets only expenses (not incomes/future expenses/budget)
- Splash delay is fixed at 6 seconds (can feel long in production)
- Theme toggle UI is commented in settings despite theme provider existing
- Add automated tests (unit + widget) for provider calculations and conversion logic

## 11) Suggested Next QA/Engineering Steps

1. Add unit tests for:
	 - Budget calculations (`spent`, `remaining`, `ratio`, threshold logic)
	 - Income confirmation contribution into active budget
	 - Future expense purchase/undo consistency
2. Add widget tests for major flows:
	 - Add expense
	 - Confirm income
	 - Set monthly budget
	 - Export action triggers
3. Refactor to one state access strategy:
	 - Prefer provider in all screens, keep Hive internals behind providers
4. Expand reset behavior options:
	 - Allow selective reset per module (expenses/income/future/budget)
5. Add empty/loading/error UX polish across reports and forms.

---

QA Documentation generated from implementation currently present in `lib/` and dependency graph in `pubspec.yaml`.
