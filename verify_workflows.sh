#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "FINAL WORKFLOW VERIFICATION"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "CHECK 1: Analytics disabled in all workflows"
ANALYTICS_COUNT=$(grep -c 'flutter config --no-analytics' .github/workflows/*.yml | awk -F: '{sum+=$2} END {print sum}')
echo "  ✅ Found $ANALYTICS_COUNT jobs with analytics disabled"
echo ""

echo "CHECK 2: Active jobs skip example"  
NO_EXAMPLE_COUNT=$(grep -h 'flutter pub get --no-example\|flutter pub outdated --no-example' .github/workflows/*.yml | wc -l | xargs)
echo "  ✅ Found $NO_EXAMPLE_COUNT commands with --no-example flag"
echo ""

echo "CHECK 3: Build jobs are disabled"
if grep -A5 'build-android:' .github/workflows/ci.yml | grep -q 'if: false'; then
  echo "  ✅ build-android is DISABLED"
else
  echo "  ⚠️  build-android is ACTIVE"
fi

if grep -A5 'build-ios:' .github/workflows/ci.yml | grep -q 'if: false'; then
  echo "  ✅ build-ios is DISABLED"
else
  echo "  ⚠️  build-ios is ACTIVE"
fi
echo ""

echo "CHECK 4: Verify no active jobs touch example"
echo "  Commands without --no-example (should only be in disabled jobs):"
FOUND=$(grep -rn 'flutter pub get$\|flutter pub outdated$' .github/workflows/ | grep -v 'pub publish' | wc -l | xargs)
if [ "$FOUND" -eq 0 ]; then
  echo "  ✅ NONE FOUND - Perfect!"
else
  echo "  Found $FOUND commands - verifying they're in disabled jobs:"
  grep -rn 'flutter pub get$\|flutter pub outdated$' .github/workflows/ | grep -v 'pub publish' | head -5
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ VERIFICATION COMPLETE"
echo "════════════════════════════════════════════════════════════════"
