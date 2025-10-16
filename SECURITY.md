# Security Policy

## Overview

ClaudeBox takes security seriously. As a Docker-based development environment for Claude CLI that runs in privileged contexts, we implement comprehensive security measures to protect against supply chain attacks, code injection, and other vulnerabilities.

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 2.x.x   | :white_check_mark: |
| 1.x.x   | :x:                |

## Security Measures

ClaudeBox implements multiple layers of security controls:

### Static Analysis
- **ShellCheck**: Automated bash security scanning on every commit
- **Semgrep**: SAST scanning for code injection vulnerabilities
- **Pre-commit hooks**: Local security validation before code is committed

### Container Security
- **Trivy**: Daily CVE scanning of base images and dependencies
- **Dockerfile best practices**: CIS Docker Benchmark compliance
- **Regular base image updates**: Automated security patches

### Supply Chain Security
- **SBOM Generation**: Software Bill of Materials for transparency
- **Dependency verification**: Checksum validation for downloaded binaries
- **APT package verification**: GPG signature checks for all packages

### Secret Protection
- **TruffleHog**: Automated secret scanning with verification
- **detect-secrets**: Baseline approach to prevent credential leakage
- **Git history scanning**: Weekly scans of full repository history

### Code Quality
- **Input validation**: All external input is validated and sanitized
- **No eval with user input**: Strict prohibition on dangerous patterns
- **Quoted variables**: All bash variables properly quoted

## Reporting a Vulnerability

We appreciate security researchers and users who help keep ClaudeBox secure.

### Where to Report

**For security vulnerabilities, please DO NOT open a public GitHub issue.**

Instead, please report security issues via:

1. **GitHub Security Advisories** (Preferred):
   - Go to https://github.com/bdmorin/claudebox/security/advisories
   - Click "Report a vulnerability"
   - Provide detailed information about the vulnerability

2. **Email** (Alternative):
   - Send details to: security@[maintainer-domain]
   - Use PGP encryption if possible (key available on request)

### What to Include

Please provide as much information as possible:

- **Description**: Clear description of the vulnerability
- **Impact**: What an attacker could achieve
- **Steps to Reproduce**: Detailed steps to demonstrate the issue
- **Affected Versions**: Which versions are vulnerable
- **Proof of Concept**: Code or commands demonstrating the vulnerability
- **Suggested Fix**: If you have ideas for remediation

### Response Timeline

We are committed to timely responses:

- **Initial Response**: Within 48 hours
- **Triage**: Within 1 week
- **Fix Development**: Depends on severity
  - Critical: Within 7 days
  - High: Within 14 days
  - Medium: Within 30 days
  - Low: Next scheduled release
- **Public Disclosure**: After fix is released and users have time to update (typically 7-14 days)

### Disclosure Policy

We follow coordinated vulnerability disclosure:

1. **Private Disclosure**: Report received and acknowledged
2. **Investigation**: We investigate and develop a fix
3. **Fix Released**: Security patch released to supported versions
4. **Public Advisory**: After reasonable time for users to update
5. **Credit**: Security researcher credited (if desired)

## Security Best Practices for Users

### API Key Security

**NEVER commit API keys to version control:**

```bash
# ❌ BAD - API keys in shell config
echo 'export ANTHROPIC_API_KEY=sk-ant-...' >> ~/.bashrc

# ✅ GOOD - Use .env files (gitignored)
echo 'ANTHROPIC_API_KEY=sk-ant-...' > .env
```

### Container Security

**Run with appropriate security settings:**

```bash
# Default (recommended) - No sudo, firewall enabled
claudebox

# Only if absolutely necessary
claudebox --enable-sudo --disable-firewall
```

### Network Security

**Use the firewall allowlist:**

```bash
# View and edit allowed domains
claudebox allowlist

# Only allow necessary domains
# - api.anthropic.com (Claude API)
# - github.com (Version control)
# - registry.npmjs.org (Node packages)
```

### Keep ClaudeBox Updated

```bash
# Check for updates regularly
claudebox update

# Subscribe to security advisories
# Watch this repository on GitHub
```

## Known Security Considerations

### Docker Privileges

ClaudeBox containers have access to:
- Your project directory (mounted as /workspace)
- Claude configuration (~/.claude)
- Network access (controlled by firewall)

**Mitigation**: Firewall enabled by default, sudo disabled by default

### Downloaded Binaries

ClaudeBox downloads and installs:
- GitHub CLI (gh)
- Delta (git diff viewer)
- Claude CLI (via npm)

**Mitigation**:
- All downloads from official sources
- Checksums verified where available
- Trivy scans all installed packages

### Profile Installations

Development profiles install packages via apt/npm/pip.

**Mitigation**:
- Only official package repositories used
- GPG signatures verified for apt packages
- npm audit runs on all Node.js packages
- Trivy scans all layers for CVEs

## Security Scanning

ClaudeBox is continuously scanned:

- **Daily**: Trivy container vulnerability scans
- **Weekly**: TruffleHog secret scans of full git history
- **Every Commit**: ShellCheck, secret detection, Bats tests
- **Every PR**: Comprehensive security pipeline

## Acknowledgments

We thank the security researchers and community members who help keep ClaudeBox secure:

<!-- Security researchers who report vulnerabilities will be listed here -->

## Contact

For general security questions (non-vulnerabilities):
- Open a GitHub Discussion
- Tag issues with "security" label

For security vulnerabilities:
- Use GitHub Security Advisories
- Or email security contact (see "Reporting a Vulnerability" above)

---

**Last Updated**: October 16, 2025

**Security Policy Version**: 1.0.0
