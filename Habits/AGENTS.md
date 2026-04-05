# Repository Guidelines

## Project Structure & Module Organization
This is an Xcode iOS project with app, widget, and shared code:
- `Habits/`: main app target (SwiftUI screens, domain models, services, settings, onboarding, export).
- `HabitsWidget/`: widget extension code and widget-specific assets.
- `Shared/`: types shared between app and widget (for example `WidgetHabit` and data store helpers).
- `HabitsTests/`: unit test suites grouped by domain (`Service/`, `Insights/`, `Heatmap/`, `Persistence/`, etc.).
- `HabitsUITests/`: UI test target (currently minimal/template-level coverage).
- `Habits.xcodeproj/` and `Habits.xctestplan`: project/scheme and test plan configuration.

## Build, Test, and Development Commands
- Build app (macOS destination, no signing):  
  `xcodebuild -quiet -scheme Habits -destination 'platform=macOS,arch=arm64' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
- Run full test suite:  
  `xcodebuild -quiet -scheme Habits -destination 'platform=macOS,arch=arm64' test`
- Run focused tests:  
  `xcodebuild -quiet -scheme Habits -destination 'platform=macOS,arch=arm64' test -only-testing:HabitsTests/HabitBehaviorTests`
- Scripted simulator run:  
  `bash Habits/Scripts/run-tests.sh`

## Coding Style & Naming Conventions
- Language: Swift with SwiftUI-first architecture.
- Follow Xcode defaults: 4-space indentation, braces on declaration line, trailing commas only when they improve diffs.
- Use `UpperCamelCase` for types and `lowerCamelCase` for properties/functions.
- Keep files focused by feature/domain; place shared logic in `Service/` or `Models/`, not view files.
- Name extensions with `Type+capability.swift` (for example `Habit+progress.swift`).

## Testing Guidelines
- Add or update unit tests for all behavior changes, especially in `Service`, `Insights`, and persistence flows.
- Test files should end with `Tests.swift`; test methods should read as behavior statements (for example `testSyncHabitReminderWhenHabitCompletedTodayDoesNotSchedule`).
- Prefer deterministic fixtures from `HabitsTests/TestSupport/`.

## Commit & Pull Request Guidelines
- Recent history uses Conventional Commit-style prefixes (`feat:`, `fix:`). Keep subjects short and imperative.
- Keep commits scoped to one change area; avoid mixing refactors with behavior changes.
- PRs should include:
  1. What changed and why.
  2. Test evidence (commands run and results).
  3. Screenshots/video for UI changes (app or widget).
