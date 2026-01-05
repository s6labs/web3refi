# Security Policy

The security of web3refi is a top priority for S6 Labs LLC. We take all security vulnerabilities seriously and appreciate the community's efforts in responsibly disclosing issues.

---

## Supported Versions

We provide security updates for the following versions:

| Version | Support Status |
|---------|----------------|
| 1.x.x   | ✅ Active support — security patches released |
| 0.9.x   | ⚠️ Limited support — critical issues only |
| < 0.9   | ❌ No support — please upgrade |

**Recommendation:** Always use the latest stable version.

---

## Reporting a Vulnerability

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Instead, report vulnerabilities privately via:

**Email:** security@s6labs.com

**PGP Key:** Available at https://s6labs.com/.well-known/pgp-key.txt (optional)

### What to Include

Please provide as much information as possible:

```
1. Type of vulnerability (e.g., RCE, XSS, data exposure)
2. Affected component (file path, function name)
3. Step-by-step reproduction instructions
4. Proof of concept (code, screenshots, video)
5. Potential impact assessment
6. Suggested fix (if any)
7. Your contact information for follow-up
```

### Example Report

```
Subject: [SECURITY] RPC Client credential exposure

Type: Information Disclosure
Component: lib/src/core/rpc_client.dart
Severity: High

Description:
When logging is enabled, the RPC client logs full request bodies 
which may include sensitive transaction data...

Steps to Reproduce:
1. Enable logging in Web3RefiConfig
2. Make a transaction
3. Check console output

Impact:
Sensitive transaction data could be exposed in logs...

Suggested Fix:
Redact sensitive fields before logging...
```

---

## Response Process

### Timeline

| Stage | Timeframe |
|-------|-----------|
| Acknowledgment | Within 24 hours |
| Initial triage | Within 48 hours |
| Status update | Within 7 days |
| Fix development | Depends on severity |
| Public disclosure | After fix is released |

### What to Expect

1. **Acknowledgment** — We'll confirm receipt of your report
2. **Triage** — We'll assess severity and validity
3. **Updates** — We'll keep you informed of progress
4. **Fix** — We'll develop and test a patch
5. **Release** — We'll release the fix
6. **Disclosure** — We'll publish a security advisory
7. **Credit** — We'll credit you (unless you prefer anonymity)

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| **Critical** | Remote code execution, private key exposure | 24-48 hours |
| **High** | Data leakage, authentication bypass | 1 week |
| **Medium** | Limited data exposure, DoS | 2 weeks |
| **Low** | Minor issues, hardening | Next release |

---

## Security Best Practices

When using web3refi in your applications:

### 1. Never Store Private Keys

web3refi is designed so private keys stay in wallet apps. **Never:**

```dart
// ❌ NEVER DO THIS
final privateKey = '0xabc123...';
final credentials = EthPrivateKey.fromHex(privateKey);
```

**Always** use wallet signing:

```dart
// ✅ CORRECT — wallet handles signing
await Web3Refi.instance.connect();
await token.transfer(to: recipient, amount: amount);
```

### 2. Validate All Addresses

Always validate addresses before transactions:

```dart
// ✅ Validate before use
bool isValidAddress(String address) {
  if (!address.startsWith('0x')) return false;
  if (address.length != 42) return false;
  // Additional validation...
  return true;
}

if (!isValidAddress(recipient)) {
  throw ArgumentError('Invalid address');
}
```

### 3. Use Testnets First

Always test on testnets before mainnet:

```dart
// ✅ Development config
await Web3Refi.initialize(
  config: Web3RefiConfig.development(
    projectId: 'xxx',
  ),
);
```

### 4. Verify Transaction Details

Always show users what they're signing:

```dart
// ✅ Show confirmation dialog
final confirmed = await showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Confirm Transfer'),
    content: Text('Send $amount to $recipient?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirm')),
    ],
  ),
);

if (confirmed == true) {
  await token.transfer(to: recipient, amount: amount);
}
```

### 5. Keep Dependencies Updated

Regularly update web3refi and dependencies:

```bash
flutter pub upgrade
flutter pub outdated
```

### 6. Secure Session Storage

web3refi uses `flutter_secure_storage` for sessions. Ensure your app doesn't expose this data:

```dart
// ❌ Don't log sensitive data
print('Session: ${Web3Refi.instance.walletManager.sessionTopic}');

// ✅ Keep sensitive data private
```

### 7. Handle Errors Securely

Don't expose internal errors to users:

```dart
try {
  await Web3Refi.instance.connect();
} on WalletException catch (e) {
  // ✅ Show user-friendly message
  showError(e.toUserMessage());
  
  // ✅ Log details privately for debugging
  debugPrint('Wallet error: ${e.code} - ${e.message}');
}
```

### 8. Use HTTPS Only

Ensure all RPC endpoints use HTTPS:

```dart
// ✅ Always HTTPS
final chain = Chain(
  rpcUrl: 'https://eth.llamarpc.com',  // ✅
  // rpcUrl: 'http://...',  // ❌ Never HTTP
);
```

---

## Known Security Considerations

### Wallet App Trust

web3refi relies on external wallet apps for signing. Users should:

- Only install wallet apps from official sources
- Verify transaction details in the wallet before signing
- Be cautious of phishing attempts

### RPC Provider Trust

RPC endpoints can potentially:

- See transaction data (though not private keys)
- Censor transactions
- Provide false data

**Mitigation:** Use reputable RPC providers and consider running your own node for sensitive applications.

### Session Persistence

Saved sessions could be accessed if device is compromised. Users should:

- Use device encryption
- Log out on shared devices
- Clear sessions when needed: `await Web3Refi.instance.clearSession()`

---

## Security Audits

### Completed Audits

| Date | Auditor | Scope | Report |
|------|---------|-------|--------|
| TBD | TBD | Full library | Link |

### Planned Audits

We plan to conduct professional security audits before major releases. If you're interested in sponsoring an audit, contact us at security@s6labs.com.

---

## Bug Bounty

We currently do not have a formal bug bounty program. However, we deeply appreciate responsible disclosure and will:

- Credit researchers in our security advisories
- Provide a letter of appreciation
- Consider monetary rewards for critical vulnerabilities

If you're interested in sponsoring a bug bounty program for web3refi, please contact us.

---

## Security Updates

### Receiving Updates

Stay informed about security updates:

- **Watch** this repository on GitHub
- Follow [@web3refi](https://twitter.com/web3refi) on Twitter
- Join our [Discord](https://discord.gg/web3refi)
- Subscribe to [GitHub Security Advisories](https://github.com/web3refi/web3refi/security/advisories)

### Past Security Advisories

| Date | Advisory | Severity | Fixed In |
|------|----------|----------|----------|
| None yet | — | — | — |

---

## Contact

- **Security issues:** security@s6labs.com
- **General inquiries:** hello@s6labs.com
- **Discord:** https://discord.gg/web3refi

---

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

*No submissions yet — be the first!*

---

**Maintained by [S6 Labs LLC](https://s6labs.com)**

*Last updated: January 2025*
