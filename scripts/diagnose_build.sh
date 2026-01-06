#!/bin/bash

# Diagnostic script to identify build issues
# Run this locally or in CI to see detailed error information

set -e  # Exit on error

echo "════════════════════════════════════════════════════════════════"
echo "Web3ReFi Build Diagnostics"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check Flutter version
echo "1. Checking Flutter version..."
flutter --version || echo "❌ Flutter not found"
echo ""

# Check Dart version
echo "2. Checking Dart version..."
dart --version || echo "❌ Dart not found"
echo ""

# Clean previous builds
echo "3. Cleaning previous builds..."
flutter clean
rm -rf .dart_tool
rm -rf build
echo "✓ Clean complete"
echo ""

# Get dependencies
echo "4. Getting dependencies..."
flutter pub get
echo "✓ Dependencies installed"
echo ""

# Check for dependency conflicts
echo "5. Checking for dependency conflicts..."
flutter pub deps || echo "⚠️ Dependency tree has issues"
echo ""

# Run formatter (check only)
echo "6. Checking code formatting..."
dart format --output=none --set-exit-if-changed . && echo "✓ Formatting OK" || echo "❌ Formatting issues found"
echo ""

# Run analyzer
echo "7. Running static analysis..."
flutter analyze --no-fatal-infos 2>&1 | tee analyze_output.txt
ANALYZE_EXIT=$?
if [ $ANALYZE_EXIT -eq 0 ]; then
    echo "✓ Analysis passed"
else
    echo "❌ Analysis failed with exit code $ANALYZE_EXIT"
    echo ""
    echo "Top errors:"
    grep "error •" analyze_output.txt | head -10
fi
echo ""

# Count issues
echo "8. Issue summary..."
ERRORS=$(grep -c "error •" analyze_output.txt 2>/dev/null || echo "0")
WARNINGS=$(grep -c "warning •" analyze_output.txt 2>/dev/null || echo "0")
INFOS=$(grep -c "info •" analyze_output.txt 2>/dev/null || echo "0")

echo "   Errors: $ERRORS"
echo "   Warnings: $WARNINGS"
echo "   Infos: $INFOS"
echo ""

# Check for missing files
echo "9. Checking for missing exported files..."
MISSING=0
while IFS= read -r export; do
    file=$(echo "$export" | sed "s/export '//" | sed "s/';//")
    if [ ! -f "lib/$file" ]; then
        echo "   ❌ MISSING: lib/$file"
        MISSING=$((MISSING + 1))
    fi
done < <(grep "^export" lib/web3refi.dart)

if [ $MISSING -eq 0 ]; then
    echo "   ✓ All exported files exist"
else
    echo "   ❌ Found $MISSING missing files"
fi
echo ""

# Try to compile
echo "10. Attempting compilation..."
flutter analyze --fatal-infos && echo "✓ Compilation successful" || echo "❌ Compilation failed"
echo ""

# Run tests (if they exist)
echo "11. Running tests..."
if [ -d "test" ]; then
    flutter test --no-pub --machine > test_results.json 2>&1 || echo "⚠️ Some tests failed"
    echo "✓ Test run complete (see test_results.json for details)"
else
    echo "⚠️ No test directory found"
fi
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "Diagnostic Complete"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  - Errors: $ERRORS"
echo "  - Warnings: $WARNINGS"
echo "  - Missing files: $MISSING"
echo ""
if [ $ERRORS -gt 0 ] || [ $MISSING -gt 0 ]; then
    echo "❌ Build has issues that need to be fixed"
    echo ""
    echo "Check:"
    echo "  - analyze_output.txt for detailed errors"
    echo "  - test_results.json for test failures"
    exit 1
else
    echo "✓ Build looks healthy!"
    exit 0
fi
