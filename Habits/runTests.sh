#!/bin/bash

SCHEME="Habits"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

TEST_CLASSES=$(grep -R "class .*Tests" -n HabitsTests | sed -E 's|.*/(.*)\.swift.*class ([A-Za-z0-9_]+).*|\2|' | sort -u)

for CLASS in $TEST_CLASSES; do
  echo "=============================="
  echo "Running $CLASS"
  echo "=============================="

  xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:HabitsTests/$CLASS \
    -quiet

  if [ $? -ne 0 ]; then
    echo "❌ $CLASS FAILED or CRASHED"
  else
    echo "✅ $CLASS PASSED"
  fi
done
