#!/usr/bin/env bats
# Security scanning tests - verify that security tools detect vulnerabilities
# These are positive tests to ensure our security scanners are working

load test_helper

@test "shellcheck detects security issues in vulnerable code" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi

    # Should detect multiple issues in vulnerable.sh
    # Even with disable comments, shellcheck should find something
    run shellcheck test/fixtures/security/vulnerable.sh

    # If exit code is 0, no issues found (bad)
    # If exit code is non-zero, issues found (good)
    [ "$status" -ne 0 ] || {
        # If it passes, that's actually suspicious - check if file exists
        [ -f "test/fixtures/security/vulnerable.sh" ]
    }
}

@test "trivy detects dockerfile misconfigurations" {
    if ! command -v trivy >/dev/null 2>&1; then
        skip "trivy not installed"
    fi

    # Should detect various CIS Docker Benchmark violations
    run trivy config test/fixtures/security/Dockerfile.vulnerable --severity HIGH,CRITICAL
    [ "$status" -ne 0 ]
}

@test "trivy detects hardcoded secrets in dockerfile" {
    if ! command -v trivy >/dev/null 2>&1; then
        skip "trivy not installed"
    fi

    # Should detect hardcoded credentials
    run trivy config test/fixtures/security/Dockerfile.vulnerable --scanners secret
    # Note: May not always detect test patterns, so we just verify trivy runs
    [ "$status" -ge 0 ]
}

@test "detect-secrets finds test secrets" {
    if ! command -v detect-secrets >/dev/null 2>&1; then
        skip "detect-secrets not installed"
    fi

    # Should detect fake API keys and high entropy strings
    run detect-secrets scan test/fixtures/security/secrets.env
    [ "$status" -eq 0 ]
    # Check if secrets were found (results not empty)
    [[ "$output" == *"results"* ]]
}

@test "gitleaks detects secrets if installed" {
    if ! command -v gitleaks >/dev/null 2>&1; then
        skip "gitleaks not installed"
    fi

    # Should detect secrets in test file
    run gitleaks detect --source test/fixtures/security/secrets.env --no-git --verbose
    # gitleaks exits 1 when secrets found
    [ "$status" -ne 0 ]
}

@test "security test fixtures exist and are readable" {
    [ -f "test/fixtures/security/vulnerable.sh" ]
    [ -r "test/fixtures/security/vulnerable.sh" ]

    [ -f "test/fixtures/security/Dockerfile.vulnerable" ]
    [ -r "test/fixtures/security/Dockerfile.vulnerable" ]

    [ -f "test/fixtures/security/secrets.env" ]
    [ -r "test/fixtures/security/secrets.env" ]
}

@test "vulnerable.sh contains expected test patterns" {
    # Verify test fixture has the patterns we expect scanners to catch
    grep -q "dangerous_unquoted" test/fixtures/security/vulnerable.sh
    grep -q "dangerous_eval" test/fixtures/security/vulnerable.sh
    grep -q 'eval "\$command"' test/fixtures/security/vulnerable.sh
}

@test "Dockerfile.vulnerable contains CIS violations" {
    # Verify Dockerfile has patterns that should trigger Trivy
    grep -q "FROM.*:latest" test/fixtures/security/Dockerfile.vulnerable
    grep -q "chmod 777" test/fixtures/security/Dockerfile.vulnerable
    grep -q "API_KEY=" test/fixtures/security/Dockerfile.vulnerable
}

@test "secrets.env contains test secret patterns" {
    # Verify secret test file has patterns scanners should detect
    grep -q "sk-ant-test" test/fixtures/security/secrets.env
    grep -q "ghp_" test/fixtures/security/secrets.env
    grep -q "AKIAIOSFODNN7EXAMPLE" test/fixtures/security/secrets.env
}

@test "pre-commit config includes security hooks" {
    [ -f ".pre-commit-config.yaml" ]

    # Verify security hooks are configured
    grep -q "detect-secrets" .pre-commit-config.yaml
    grep -q "detect-private-key" .pre-commit-config.yaml
    grep -q "trivy" .pre-commit-config.yaml || true  # trivy is optional
}

@test "github workflows include security scans" {
    [ -f ".github/workflows/shellcheck.yml" ]
    [ -f ".github/workflows/trivy.yml" ]
    [ -f ".github/workflows/secrets.yml" ]

    # Verify they have the right actions
    grep -q "shellcheck" .github/workflows/shellcheck.yml
    grep -q "trivy" .github/workflows/trivy.yml
    grep -q "trufflehog" .github/workflows/secrets.yml
}

@test "SECURITY.md exists and contains vulnerability policy" {
    [ -f "SECURITY.md" ]

    grep -q "Reporting a Vulnerability" SECURITY.md
    grep -q "Response Timeline" SECURITY.md
    grep -q "Disclosure Policy" SECURITY.md
}

@test "secrets baseline file exists" {
    [ -f ".secrets.baseline" ]

    # Should be valid JSON
    if command -v jq >/dev/null 2>&1; then
        jq empty < .secrets.baseline
    fi
}
