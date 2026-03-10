#
//  run-tests.sh
//  Habits
//
//  Created by Matt Adams on 10/03/2026.
//

#!/bin/bash

set -e

echo "Running Habits test suite..."

PROJECT="Habits.xcodeproj"
SCHEME="Habits"
DESTINATION="platform=iOS Simulator,name=iPhone 16"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -configuration Debug \
  test \
  | xcpretty

echo "Tests completed."
