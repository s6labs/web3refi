# Contributing to web3refi

Thank you for your interest in contributing to web3refi! This document provides guidelines and information for contributors.

**Created and maintained by S6 Labs LLC**

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Community](#community)

---

## Code of Conduct

This project adheres to our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold a welcoming, inclusive, and harassment-free environment for everyone.

**TL;DR:** Be kind, be respectful, be professional.

---

## Getting Started

### Prerequisites

- Flutter SDK >= 3.10.0
- Dart SDK >= 3.0.0
- Git
- A code editor (VS Code recommended)
- A GitHub account

### Quick Start

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/web3refi.git
cd web3refi

# 3. Add upstream remote
git remote add upstream https://github.com/AguaClara/web3refi.git

# 4. Install dependencies
flutter pub get

# 5. Run tests to verify setup
flutter test

# 6. Run the example app
cd example
flutter run
```

---

## Development Setup

### Recommended VS Code Extensions

```json
{
  "recommendations": [
    "Dart-Code.dart-code",
    "Dart-Code.flutter",
    "streetsidesoftware.code-spell-checker",
    "eamodio.gitlens",
    "usernamehw.errorlens"
  ]
}
```

### VS Code Settings

```json
{
  "dart.lineLength": 100,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  }
}
```

### Project Structure

```
web3refi/
├── lib/                 # Library source code
│   ├── web3refi.dart    # Main exports
│   └── src/             # Implementation
├── test/                # Unit and integration tests
├── example/             # Example Flutter app
├── doc/                 # Documentation
└── tool/                # Development scripts
```

---

## How to Contribute

### Reporting Bugs

Before submitting a bug report:

1. **Search existing issues** to avoid duplicates
2. **Update to the latest version** to see if the bug persists
3. **Collect information** about your environment

When submitting, include:

- Clear, descriptive title
- Steps to reproduce
- Expected vs actual behavior
- Environment details (Flutter version, platform, device)
- Code samples or screenshots if applicable

### Suggesting Features

We welcome feature suggestions! Please:

1. **Check existing issues** and discussions first
2. **Explain the use case** — why is this feature needed?
3. **Describe the solution** you'd like
4. **Consider alternatives** you've thought about

### Submitting Code

Types of contributions we're looking for:

- Bug fixes
- New features (discuss first in an issue)
- Performance improvements
- Documentation improvements
- Test coverage improvements
- Refactoring (with clear justification)

---

## Pull Request Process

### Branch Naming

```
feature/add-avalanche-support
fix/wallet-connection-timeout
docs/improve-getting-started
refactor/simplify-rpc-client
test/add-erc20-tests
```

### Workflow

1. **Create an issue** first (for significant changes)
2. **Fork and clone** the repository
3. **Create a branch** from `main`
4. **Make your changes** with clear commits
5. **Write/update tests** for your changes
6. **Update documentation** if needed
7. **Run all checks locally**:
   ```bash
   flutter analyze
   dart format .
   flutter test
   ```
8. **Push and create PR** against `main`
9. **Respond to feedback** from reviewers

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change that neither fixes nor adds
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```
feat(wallet): add Phantom wallet support for Solana

fix(rpc): handle timeout errors gracefully

docs(readme): add migration guide from web3dart

test(erc20): add transfer function tests
```

### PR Checklist

Before submitting your PR, ensure:

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated (if applicable)
- [ ] Tests added/updated
- [ ] All tests pass locally
- [ ] No new analyzer warnings
- [ ] CHANGELOG.md updated (for user-facing changes)
- [ ] PR description explains the changes

---

## Coding Standards

### Dart Style

We follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines with these specifics:

**Line Length:** 100 characters

**Imports:** Organized in sections
```dart
// Dart SDK
import 'dart:async';
import 'dart:convert';

// Flutter
import 'package:flutter/material.dart';

// External packages
import 'package:http/http.dart' as http;

// Internal packages
import 'package:web3refi/src/core/rpc_client.dart';
```

**Naming:**
```dart
// Classes: UpperCamelCase
class WalletManager {}

// Variables, functions: lowerCamelCase
final walletAddress = '0x...';
void connectWallet() {}

// Constants: lowerCamelCase
const defaultTimeout = Duration(seconds: 30);

// Private: prefix with underscore
String _privateField;
void _privateMethod() {}
```

**Documentation:**
```dart
/// A brief description of the class.
///
/// More detailed description if needed.
/// Can span multiple lines.
///
/// Example:
/// ```dart
/// final client = RpcClient(chain: Chains.ethereum);
/// final balance = await client.getBalance(address);
/// ```
class RpcClient {
  /// Gets the balance for [address].
  ///
  /// Returns the balance in wei as [BigInt].
  ///
  /// Throws [RpcException] if the request fails.
  Future<BigInt> getBalance(String address) async {
    // Implementation
  }
}
```

### Error Handling

Always use typed exceptions:

```dart
// Good
throw WalletException.notConnected();
throw RpcException.timeout();

// Avoid
throw Exception('Not connected');
throw 'Error message';
```

### Null Safety

Embrace null safety properly:

```dart
// Good
final String? address;
if (address != null) {
  print(address.length);
}

// Also good
final length = address?.length ?? 0;

// Avoid (unless certain)
print(address!.length);
```

---

## Testing Guidelines

### Test Structure

```
test/
├── core/
│   ├── rpc_client_test.dart
│   └── web3refi_test.dart
├── wallet/
│   └── wallet_manager_test.dart
├── defi/
│   └── erc20_test.dart
├── mocks/
│   ├── mock_http_client.dart
│   └── mock_wallet_manager.dart
└── test_utils.dart
```

### Writing Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';

void main() {
  group('ERC20', () {
    late ERC20 token;
    late MockRpcClient mockRpc;

    setUp(() {
      mockRpc = MockRpcClient();
      token = ERC20(
        address: '0x123...',
        rpcClient: mockRpc,
      );
    });

    tearDown(() {
      // Cleanup if needed
    });

    test('balanceOf returns correct balance', () async {
      // Arrange
      mockRpc.mockResponse('eth_call', '0x1234');

      // Act
      final balance = await token.balanceOf('0xabc...');

      // Assert
      expect(balance, equals(BigInt.from(0x1234)));
    });

    test('transfer throws on insufficient balance', () async {
      // Arrange
      mockRpc.mockResponse('eth_call', '0x0'); // Zero balance

      // Act & Assert
      expect(
        () => token.transfer(to: '0x...', amount: BigInt.from(100)),
        throwsA(isA<TransactionException>()),
      );
    });
  });
}
```

### Test Coverage

- Aim for **80%+ code coverage**
- All public APIs must have tests
- Test both success and error cases
- Include edge cases

Run coverage report:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Documentation

### Code Documentation

All public APIs must be documented:

```dart
/// Connects to a wallet using WalletConnect.
///
/// This method will:
/// 1. Generate a WalletConnect session
/// 2. Open the user's wallet app
/// 3. Wait for approval
///
/// The [preferredChain] parameter specifies which chain to connect to.
/// If not provided, uses the default chain from config.
///
/// Throws [WalletException] if:
/// - User rejects the connection
/// - Connection times out
/// - Wallet app is not installed
///
/// Example:
/// ```dart
/// try {
///   await Web3Refi.instance.connect(
///     preferredChain: Chains.polygon,
///   );
///   print('Connected: ${Web3Refi.instance.address}');
/// } on WalletException catch (e) {
///   print('Failed: ${e.message}');
/// }
/// ```
Future<void> connect({Chain? preferredChain}) async {
```

### Documentation Files

When adding features, update relevant docs:

- `doc/getting-started.md` — Installation and setup
- `doc/wallet-connection.md` — Wallet features
- `doc/token-operations.md` — Token/DeFi features
- `README.md` — If it's a major feature

---

## Community

### Getting Help

- **Discord:** [discord.gg/web3refi](https://discord.gg/web3refi)
- **GitHub Discussions:** For questions and ideas
- **Stack Overflow:** Tag with `web3refi`

### Recognition

Contributors are recognized in:

- `CONTRIBUTORS.md` file
- Release notes
- Our website's contributors page

### Becoming a Maintainer

Active contributors may be invited to become maintainers. This involves:

- Reviewing PRs
- Triaging issues
- Helping with releases
- Guiding the project direction

---

## License

By contributing to web3refi, you agree that your contributions will be licensed under the MIT License.

---

## Questions?

Don't hesitate to ask! Open an issue, start a discussion, or reach out on Discord.

**Thank you for contributing to web3refi!** 🙏

---

*Created with 💙 by S6 Labs LLC*
