# How to Check GitHub Actions Errors

**Date**: January 6, 2026

Now that we've added verbose error reporting, here's how to see the actual errors causing the build failures.

---

## Step 1: Go to GitHub Actions

1. **Visit**: https://github.com/s6labs/web3refi/actions
2. **Click** on the most recent workflow run (top of the list)
3. You'll see a list of jobs with ❌ red X marks for failures

---

## Step 2: Click on a Failed Job

Example failing jobs:
- **CI / Analyze & Format**
- **CI / Run Tests**
- **Security / Static Security Analysis**

Click on any job with a red ❌ to see its details.

---

## Step 3: Expand the Failed Step

Inside the job, you'll see steps like:
- ✅ Checkout code
- ✅ Setup Flutter
- ❌ Install dependencies  ← **CLICK HERE**
- ❌ Analyze code

Click on the step with the red ❌ to see the error output.

---

## Step 4: Look for Error Messages

With the new verbose output, you'll see:

### **If `flutter pub get` fails:**
```
Installing dependencies...
Because web3refi depends on package_name ^1.0.0 which doesn't exist, version solving failed.
❌ flutter pub get failed
```

### **If static analysis fails:**
```
Running static analysis...
❌ Static analysis failed

=== Top 20 Errors ===
error • Undefined name 'SomeClass' • lib/src/some_file.dart:42:12
error • The getter 'someMethod' isn't defined for the type 'SomeType' • lib/src/other_file.dart:156:8
...
```

### **If tests fail:**
```
Running tests with coverage...
❌ Tests failed

=== Test Failures ===
FAILED: test/some_test.dart
Expected: <true>
  Actual: <false>
...
```

---

## Step 5: Common Error Patterns

### **Pattern 1: Missing Package**
```
Because web3refi depends on some_package which doesn't exist
```
**Fix**: Package name typo in pubspec.yaml or package doesn't exist

### **Pattern 2: Version Conflict**
```
Because package_a requires package_b ^2.0.0 and package_c requires package_b ^1.0.0
```
**Fix**: Update package versions in pubspec.yaml to compatible ranges

### **Pattern 3: Import Error**
```
error • Target of URI doesn't exist: 'package:web3refi/src/some_file.dart'
```
**Fix**: File is missing or path is wrong

### **Pattern 4: Undefined Class/Method**
```
error • Undefined name 'ClassName'
error • The getter 'methodName' isn't defined
```
**Fix**: Missing import or typo in code

### **Pattern 5: Type Mismatch**
```
error • A value of type 'String' can't be assigned to a variable of type 'int'
```
**Fix**: Incorrect type in code

---

## Step 6: Copy the Error and Share

Once you find the error:

1. **Select** the error text
2. **Copy** it (Cmd+C / Ctrl+C)
3. **Share** it so we can fix it

Example format:
```
Job: CI / Analyze & Format
Step: Analyze code
Error:
  error • Undefined name 'ChainConfig' • lib/src/core/web3refi_config.dart:42:12
  error • The getter 'chainId' isn't defined for the type 'Chain' • lib/src/wallet/wallet_manager.dart:156:8
```

---

## Step 7: Re-run After Fixes

After we push fixes:

1. **Go back** to https://github.com/s6labs/web3refi/actions
2. **Look for** new workflow runs (they trigger automatically on push)
3. **Wait** 5-10 minutes for completion
4. **Check** if jobs turn green ✅

---

## Quick Links

- **Actions Page**: https://github.com/s6labs/web3refi/actions
- **Latest Run**: https://github.com/s6labs/web3refi/actions/runs (click top item)
- **Repository**: https://github.com/s6labs/web3refi

---

## What to Look For in Latest Run

The latest workflow run (commit `895fe31`) has **enhanced error reporting**.

You should now see:
- ✓ Clear success/failure messages
- ❌ Top 20 errors when analysis fails
- 📋 Detailed test failure output
- 🔍 Step-by-step progress logging

This makes it **much easier** to identify the exact issue!

---

**Next Steps**:

1. Check the latest workflow run
2. Copy the error messages from the failed steps
3. Share them so we can create targeted fixes

**The verbose output will tell us EXACTLY what's wrong!**
