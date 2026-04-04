# Test Suite Audit

Date: March 11, 2026

Constraint: static audit only. No tests were executed.

## Inventory

### Unit tests

`CurrencyDetectionTests.swift`
Purpose: currency token and symbol detection.
Key production code: `CurrencyDetection`.
Decision: KEEP.

`CurrencyIntegrationTests.swift`
Purpose: currency-aware formatting across model and service layers.
Key production code: `Habit.inlineProgressText`, `HabitLogService.formattedValue`, `HabitValueFormatter`, `MetricKindResolver`.
Decision: KEEP.

`HabitInsightsEngineTests.swift`
Purpose: high-level insight cards, projections, trend messaging, behaviour coaching phrasing, and snapshot consistency.
Key production code: `HabitInsightsEngine`, `HabitInsightsEngine.snapshot`, `PaceCalculator`, `PatternCalculator`, `MetricsCalculator`.
Decision: KEEP.

`HabitInsightsEngineFoundationTests.swift`
Purpose: foundation snapshot metrics for achievement, consistency, streaks, identity state, and card ordering.
Key production code: `HabitInsightsEngine.habitInsightSnapshot`, `AchievementCalculator`, `ConsistencyCalculator`, `TrendCalculator`, streak calculation in `HabitInsightsEngine+Snapshot.swift`.
Decision: KEEP.

`TimelineContextTests.swift`
Purpose: past/live timeline handling and context labels.
Key production code: `TimelineContext`.
Decision: KEEP.

`HabitSelectionStateTests.swift`
Purpose: selected day and visible-month coordination for detail/calendar navigation.
Key production code: `HabitSelectionState`, `CalendarMonthNavigator`.
Decision: KEEP.

`CalendarProviderTests.swift`
Purpose: weekday ordering, calendar grid alignment, and heatmap weekday layout.
Key production code: `CalendarProvider`, `WeekLayoutStrategy`, `CalendarGridHelper`, `WeekBoundaryCalculator`.
Decision: KEEP.

`MetricKindTests.swift`
Purpose: count vs currency vs generic cumulative metric resolution.
Key production code: `MetricKindResolver`.
Decision: KEEP.

`ValueInputParserTests.swift`
Purpose: numeric parsing and storage sanitization rules.
Key production code: `ValueInputParser`.
Decision: KEEP.

`HeatmapNormalizerTests.swift`
Purpose: heatmap tiering for open-ended, frequency-goal, and cumulative-goal habits.
Key production code: `HeatmapNormalizer`.
Decision: KEEP.

`CalendarMonthNavigatorTests.swift`
Purpose: visible month normalization and adjacent month traversal.
Key production code: `CalendarMonthNavigator`.
Decision: KEEP.

`HeatmapLayoutServiceTests.swift`
Purpose: week grouping and fixed Monday-first heatmap geometry.
Key production code: `HeatmapLayoutService`, `WeekLayoutStrategy`, `CalendarProvider`.
Decision: KEEP.

`ValueFormatterTests.swift`
Purpose: count, generic numeric, and currency formatting rules.
Key production code: `HabitValueFormatter`.
Decision: KEEP.

`GoalProgressTests.swift`
Purpose: clamping, overflow, completion, and fraction calculations for integer goals.
Key production code: `GoalProgress`.
Decision: KEEP.

`LastValueStoreTests.swift`
Purpose: persistence-derived “last value” lookup for cumulative habits.
Key production code: `LogDerivedLastValueStore`.
Decision: KEEP.

`WeekBoundaryCalculatorTests.swift`
Purpose: configured week starts and timezone-safe week interval calculations.
Key production code: `WeekBoundaryCalculator`.
Decision: KEEP.

`HabitBehaviorTests.swift`
Purpose: habit logging, progress, streaks, period ranges, heatmap intensity, cumulative-entry migration, and inline progress text.
Key production code: `Habit`, `HabitLogService`, `GoalPeriod`, `HeatmapNormalizer`, `LastValueStore`.
Decision: KEEP.

`ProgressAsOfServiceTests.swift`
Purpose: progress snapshots for past/current periods, clamped display, overflow text, streaks, and visible-month cumulative totals.
Key production code: `ProgressAsOfService`, `HabitInsightsEngine.snapshot`, `TimelineContext`.
Decision: KEEP.

`Tests/NotificationServiceTests.swift`
Purpose: reminder scheduling, rescheduling, removal, authorization gating, and completion gating.
Key production code: `NotificationService`, `HabitLogService.isHabitCompletedToday`.
Decision: UPDATE.

`Tests/NotificationActionHandlerTests.swift`
Purpose: quick-log notification action, deep-link routing, and reminder cleanup.
Key production code: `NotificationActionHandler`, `NotificationService`, `HabitLogService`.
Decision: KEEP.

`Tests/MockNotificationCenter.swift`
Purpose: test double support for notification scheduling assertions.
Decision: KEEP as fixture support.

`Tests/TestHabitFactory.swift`
Purpose: shared habit fixtures for notification tests.
Decision: UPDATE.

`Tests/TestDatabase.swift`
Purpose: shared in-memory SwiftData container/context for tests.
Decision: KEEP as fixture support.

`HabitDetailTestFixtures.swift`
Purpose: deterministic calendars, dates, and common habit builders.
Decision: KEEP as fixture support.

### UI tests

`HabitsUITests.swift`
Purpose: Xcode template placeholder launch/performance smoke test.
Key production code: none beyond app launch.
Decision: REMOVE.

`HabitsUITestsLaunchTests.swift`
Purpose: Xcode template placeholder screenshot-on-launch test.
Key production code: none beyond app launch.
Decision: REMOVE.

## Concrete findings

### Test file
`Tests/NotificationServiceTests.swift`

Purpose of file:
Validate reminder scheduling and cancellation logic in `NotificationService`.

Test: `testSyncHabitReminderWhenHabitCompletedTodayDoesNotSchedule()`

Expected behaviour:
If a habit is complete for today, `syncHabitReminder(for:)` must cancel any pending reminder and stop before scheduling a new one.

Current implementation behaviour:
Completion is determined by `HabitLogService.isHabitCompletedToday`, which delegates to `habit.isComplete(for:)`. That only returns `true` for goal-based habits whose current-period progress reaches the configured target.

Decision:
UPDATE

Reason:
The shared `createCompletedHabit` fixture previously built an open-ended frequency habit (`hasStreakGoal == false`) with one log. Under the current architecture that habit is active, but not “complete,” so the test’s setup no longer represented the asserted state.

Applied change:
`TestHabitFactory.createCompletedHabit` now creates a daily frequency habit with `hasStreakGoal == true` and `streakTarget == 1`, which matches the real completion model used by production code.

### Test file
`Tests/NotificationServiceTests.swift`

Purpose of file:
Validate reminder scheduling and cancellation logic in `NotificationService`.

Test: `testReminderCancellationWhenCompletedTodayDoesNotSchedule()`

Expected behaviour:
Identical to `testSyncHabitReminderWhenHabitCompletedTodayDoesNotSchedule()`.

Current implementation behaviour:
Identical code path and assertion target.

Decision:
REMOVE

Reason:
Redundant duplicate coverage. Keeping both adds maintenance cost without increasing behavioural protection.

Applied change:
Removed the duplicate test.

### Test file
`Tests/TestHabitFactory.swift`

Purpose of file:
Provide reusable test fixtures for notification-related tests.

Test support audited:
`createCompletedHabit(...)`

Expected behaviour:
Produce a habit that the production completion logic considers complete on `completionDate`.

Current implementation behaviour:
After the update, the factory now produces a goal-based daily frequency habit that actually satisfies `habit.isComplete(for:)` when the log is present.

Decision:
UPDATE

Reason:
Fixture semantics were stale relative to the current goal model.

### Test file
`HabitsUITests.swift`

Purpose of file:
Template-generated UI smoke tests.

Test: `testExample()`

Expected behaviour:
Launches the app and asserts nothing.

Current implementation behaviour:
No specification value. This is not tied to any product behaviour and would not catch regressions beyond launch crashes.

Decision:
REMOVE

Reason:
Placeholder test, not a reliable specification of the system.

Test: `testLaunchPerformance()`

Expected behaviour:
Measures launch time.

Current implementation behaviour:
Not a behavioural specification and has no deterministic, architecture-level assertion.

Decision:
REMOVE

Reason:
Performance smoke benchmark is not part of the app’s behavioural contract and is currently template-generated.

### Test file
`HabitsUITestsLaunchTests.swift`

Purpose of file:
Template-generated launch screenshot test.

Test: `testLaunch()`

Expected behaviour:
Launches the app and captures a screenshot.

Current implementation behaviour:
No product assertion. It is a template artifact rather than a specification of the current app.

Decision:
REMOVE

Reason:
Placeholder UI test with no behavioural verification.

## Kept coverage summary

The remaining suite is materially aligned with the current architecture:

- Goal/progress/streak coverage maps to `Habit`, `GoalPeriod`, `GoalProgress`, and `HabitInsightsEngine.snapshot`.
- Heatmap coverage maps to `HeatmapNormalizer`, `HeatmapLayoutService`, and `WeekLayoutStrategy`; the tests correctly reflect the current split between configurable calendar calculations and fixed Monday-first heatmap rendering.
- Currency/value parsing and formatting coverage maps to `CurrencyDetection`, `MetricKindResolver`, `ValueInputParser`, and `HabitValueFormatter`.
- Notification action coverage maps to the current delegate-based `NotificationActionHandler` architecture.
- Insights coverage maps to the current engine stack (`HabitInsightsEngine`, snapshot/foundation helpers, pace, pattern, trend, activity summary, and behaviour analyzers) and still targets live concepts in production code.

## Residual risk

- Because the suite was not executed, this audit cannot prove there are no latent compile failures in untouched tests.
- The insights files contain the largest number of expectation-heavy string assertions; they appear aligned to the current engine code on inspection, but they remain the area with the highest ongoing drift risk if phrasing changes again.
