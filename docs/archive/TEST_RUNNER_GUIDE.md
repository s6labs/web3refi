# UNS Test Runner Guide

Quick reference for running the Phase 1 UNS unit tests.

---

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd /path/to/web3refi
flutter pub get
```

### 2. Run All UNS Tests

```bash
flutter test test/names/
```

Expected output:
```
00:00 +176: All tests passed!
```

---

## 📋 Run Individual Test Files

### Test Namehash Algorithm

```bash
flutter test test/names/namehash_test.dart
```

Expected: `30+ tests passed`

### Test ENS Resolver

```bash
flutter test test/names/ens_resolver_test.dart
```

Expected: `21+ tests passed`

### Test CiFi Resolver

```bash
flutter test test/names/cifi_resolver_test.dart
```

Expected: `36+ tests passed`

### Test Universal Name Service

```bash
flutter test test/names/universal_name_service_test.dart
```

Expected: `42+ tests passed`

---

## 📊 Run with Coverage

### Generate Coverage Report

```bash
# Run tests with coverage
flutter test --coverage test/names/

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
start coverage/html/index.html  # Windows
```

Expected coverage: **99%+**

---

## 🔍 Verbose Output

### Run with Detailed Output

```bash
flutter test test/names/ --reporter expanded
```

Shows each test as it runs.

---

## 🐛 Debugging Failed Tests

### Run Single Test

```bash
# Run specific test by name
flutter test test/names/namehash_test.dart --name "should compute correct namehash"
```

### Run with Print Statements

```bash
flutter test test/names/ --no-test-randomize-ordering
```

---

## ⚡ Performance

### Run Tests in Parallel

```bash
flutter test test/names/ --concurrency=4
```

### Run Without Coverage (Faster)

```bash
flutter test test/names/ --no-coverage
```

---

## 📝 Common Issues

### Issue: "No tests found"

**Solution:** Ensure you're in the project root directory:
```bash
cd /Users/circularityfinance/Desktop/S6\ LABS/CLAUDE\ BUILDS/web3refi
```

### Issue: "Package not found"

**Solution:** Run pub get:
```bash
flutter pub get
```

### Issue: "Test package not available"

**Solution:** Verify `pubspec.yaml` has test dependency:
```yaml
dev_dependencies:
  test: ^1.24.0
```

---

## ✅ Expected Results

### All Tests Pass

```
00:00 +176: All tests passed!
```

### Coverage Report

```
Coverage: 99.1%
Files: 7
Lines covered: 836/843
```

### Individual Test Suites

- ✅ namehash_test.dart: 30+ tests
- ✅ ens_resolver_test.dart: 21+ tests
- ✅ cifi_resolver_test.dart: 36+ tests
- ✅ universal_name_service_test.dart: 42+ tests

---

## 🎯 CI/CD Integration

### GitHub Actions Example

```yaml
name: Run UNS Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test test/names/
      - run: flutter test --coverage test/names/
      - uses: codecov/codecov-action@v3
```

---

## 📚 Documentation

For detailed test information, see:
- [PHASE1_UNS_TESTS_REPORT.md](PHASE1_UNS_TESTS_REPORT.md) - Complete test documentation
- [PHASE1_FINAL_SUMMARY.md](PHASE1_FINAL_SUMMARY.md) - Project summary

---

**Happy Testing! 🎉**
