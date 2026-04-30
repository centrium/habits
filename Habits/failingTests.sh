#!/bin/bash

set -euo pipefail

SCHEME="Habits"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

echo "----------------------------------------"
echo "Running failing test suites..."
echo "----------------------------------------"

run_suite () {
  SUITE=$1
  echo ""
  echo "➡️ Running $SUITE"
  echo "----------------------------------------"

  xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:"HabitsTests/$SUITE" \
    | tee "logs_$SUITE.txt"

  echo ""
  echo "🔍 Summary for $SUITE"
  grep -E "Test Case|error:|failed|crash|Assertion" "logs_$SUITE.txt" || true
}

# run_suite "WidgetHabitIdentityStateTests"
# run_suite "WidgetHabitSelectionTests"
run_suite "HabitLoggingArchitectureTests"

echo ""
echo "----------------------------------------"
echo "Done."
echo "----------------------------------------"
