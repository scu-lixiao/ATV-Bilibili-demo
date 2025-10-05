# 🔐 Premium 2025: Security & Sensitive Data Guide

## Overview

This project implements comprehensive security measures to prevent accidental commits of sensitive data. This guide explains the security system and best practices.

## Security Layers

### 1. Enhanced `.gitignore`

The `.gitignore` file has been enhanced with Premium 2025 patterns to block:

- **API Keys & Secrets**: `*.key`, `*.pem`, `*.p12`, `secrets.*`
- **Bilibili Credentials**: `**/Keys.swift`, `**/BilibiliKeys.swift`
- **Environment Variables**: `.env`, `.env.*` (except `.env.example`)
- **Authentication Tokens**: `*.token`, `auth.*`
- **Certificates**: `*.mobileprovision`, `*.cer`
- **Databases**: `*.db`, `*.sqlite`
- **Logs**: `*.log`, `logs/`

### 2. Pre-Commit Hook

A git pre-commit hook automatically scans staged files for:

- Sensitive file patterns (Keys.swift, credentials, etc.)
- API keys and secret keys in code
- Password and token strings
- Private key blocks
- Credit card patterns

**Location**: `.git/hooks/pre-commit`

**To test the hook**:
```bash
# Try to commit a file with "API_KEY = 'secret'"
# The hook will block it
```

### 3. Environment Template

The `.env.example` file provides a template for storing sensitive configuration without committing actual values.

**Setup**:
```bash
# 1. Copy template
cp .env.example .env

# 2. Fill in your actual credentials
vim .env

# 3. .env is gitignored, so your secrets are safe
```

## Critical Files

### ⚠️ `BilibiliLive/Keys.swift`

**STATUS**: ❌ Previously tracked by git (FIXED)

This file contains Bilibili API credentials and has been:
1. ✅ Removed from git tracking with `git rm --cached`
2. ✅ Added to `.gitignore` via `**/Keys.swift` pattern
3. ✅ Local copy preserved for development

**What happened**:
```bash
# Keys.swift was removed from git index but kept locally
git rm --cached BilibiliLive/Keys.swift
```

**Important**:
- The file still exists locally for development
- It will NEVER be committed again
- Git history still contains old commits with this file
- Consider rotating API keys if they were exposed

## Best Practices

### ✅ DO

1. **Use environment variables** for sensitive config
2. **Store secrets in Keychain** when possible
3. **Review staged files** before committing:
   ```bash
   git diff --cached
   ```
4. **Test the pre-commit hook** occasionally
5. **Use `.env.example`** as template for team members

### ❌ DON'T

1. **Never commit** files matching these patterns:
   - `*secret*`, `*credential*`, `*password*`
   - `*.key`, `*.pem`, `*.p12`
   - `Keys.swift`, `APIKeys.swift`

2. **Never hardcode** API keys in source files
3. **Never disable** the pre-commit hook without team approval
4. **Never use** `git commit --no-verify` to bypass security

## Testing Security

### Test Pre-Commit Hook

```bash
# 1. Create a test file with sensitive data
echo 'let API_KEY = "sk_test_123456"' > test_sensitive.swift
git add test_sensitive.swift

# 2. Try to commit (should be blocked)
git commit -m "test"

# 3. Clean up
git reset HEAD test_sensitive.swift
rm test_sensitive.swift
```

### Audit Current Repository

```bash
# Check for accidentally tracked sensitive files
git ls-files | grep -iE '(secret|credential|password|key|token)'

# Scan git history for sensitive patterns
git log -p | grep -iE '(API_KEY|SECRET_KEY|password\s*=)'
```

## Migration Guide

### Migrating `Keys.swift` to Secure Storage

**Current State** (Insecure):
```swift
// BilibiliLive/Keys.swift
struct Keys {
    static let appKey = "1234567890"
    static let appSecret = "abcdefghijk"
}
```

**Recommended Approach** (Secure):

#### Option 1: Environment Variables + Build Config

```swift
// BilibiliLive/Config/SecureKeys.swift
import Foundation

struct SecureKeys {
    static var appKey: String {
        guard let key = ProcessInfo.processInfo.environment["BILIBILI_APP_KEY"] else {
            fatalError("BILIBILI_APP_KEY not found in environment")
        }
        return key
    }

    static var appSecret: String {
        guard let secret = ProcessInfo.processInfo.environment["BILIBILI_APP_SECRET"] else {
            fatalError("BILIBILI_APP_SECRET not found in environment")
        }
        return secret
    }
}
```

**Xcode Configuration**:
1. Go to: Edit Scheme → Run → Arguments → Environment Variables
2. Add: `BILIBILI_APP_KEY` = `your_key_here`
3. Add: `BILIBILI_APP_SECRET` = `your_secret_here`

#### Option 2: Keychain (Most Secure)

```swift
import Security

class KeychainManager {
    static func getString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func setString(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}

// Usage
struct SecureKeys {
    static var appKey: String {
        KeychainManager.getString(key: "bilibili.app.key") ?? ""
    }
}
```

## Incident Response

### If Sensitive Data Was Committed

1. **Immediately rotate** compromised credentials
2. **Remove from git history**:
   ```bash
   # Use git-filter-repo (preferred) or BFG Repo-Cleaner
   git filter-repo --path Keys.swift --invert-paths
   ```
3. **Force push** (coordinate with team):
   ```bash
   git push origin --force --all
   ```
4. **Notify team** to re-clone repository

### If Pre-Commit Hook Fails

1. **Review the output** - it shows which file/pattern matched
2. **Fix the issue** - remove sensitive data or use environment variables
3. **Test again**: `git commit -m "..."`
4. **If false positive** - contact security lead to update hook patterns

## CI/CD Integration

For GitHub Actions / Jenkins:

```yaml
# .github/workflows/build.yml
env:
  BILIBILI_APP_KEY: ${{ secrets.BILIBILI_APP_KEY }}
  BILIBILI_APP_SECRET: ${{ secrets.BILIBILI_APP_SECRET }}
```

Store actual values in:
- **GitHub**: Settings → Secrets and variables → Actions
- **Jenkins**: Credentials → Add → Secret text

## Support

For questions or security concerns:
1. Check this guide first
2. Review `.gitignore` and `.env.example`
3. Test with pre-commit hook
4. Contact project maintainer

---

**Premium 2025 Security System** - Protecting your credentials, automatically. 🔐
