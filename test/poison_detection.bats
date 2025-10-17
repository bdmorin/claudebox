#!/usr/bin/env bats
# Test poison context detection with Semgrep

load test_helper

@test "poison test fixtures exist" {
    [ -d "test/fixtures/poison" ]
    [ -f "test/fixtures/poison/CLAUDE.md" ]
    [ -f "test/fixtures/poison/.mcp.json" ]
    [ -f "test/fixtures/poison/Dockerfile.template" ]
    [ -f "test/fixtures/poison/hidden-unicode.md" ]
    [ -f "test/fixtures/poison/encoded-payload.sh" ]
    [ -f "test/fixtures/poison/malicious.html" ]
}

@test "CLAUDE.md contains prompt injection patterns" {
    run grep -i "ignore all previous instructions" test/fixtures/poison/CLAUDE.md
    [ "$status" -eq 0 ]

    run grep -i "DAN" test/fixtures/poison/CLAUDE.md
    [ "$status" -eq 0 ]

    run grep -i "developer mode" test/fixtures/poison/CLAUDE.md
    [ "$status" -eq 0 ]
}

@test "MCP config contains dangerous commands" {
    run grep "curl.*|.*sh" test/fixtures/poison/.mcp.json
    [ "$status" -eq 0 ]

    run grep "rm -rf" test/fixtures/poison/.mcp.json
    [ "$status" -eq 0 ]

    run grep "dd if=/dev/zero" test/fixtures/poison/.mcp.json
    [ "$status" -eq 0 ]
}

@test "Dockerfile.template contains template injection" {
    run grep "{{.*[;&|]" test/fixtures/poison/Dockerfile.template
    [ "$status" -eq 0 ]

    run grep "chmod 777" test/fixtures/poison/Dockerfile.template
    [ "$status" -eq 0 ]

    run grep "\.\.\/" test/fixtures/poison/Dockerfile.template
    [ "$status" -eq 0 ]
}

@test "hidden-unicode.md contains zero-width characters" {
    # Check for zero-width characters using od/hexdump
    # Zero-width space (U+200B) = e2 80 8b in UTF-8
    run od -A n -t x1 test/fixtures/poison/hidden-unicode.md
    [ "$status" -eq 0 ]

    # Look for the UTF-8 byte sequence e2 80 8b (zero-width space)
    printf '%s' "$output" | grep -q "e2.*80.*8b"
    [ $? -eq 0 ]
}

@test "encoded-payload.sh contains base64 encoded commands" {
    run grep "base64" test/fixtures/poison/encoded-payload.sh
    [ "$status" -eq 0 ]

    run grep "xxd" test/fixtures/poison/encoded-payload.sh
    [ "$status" -eq 0 ]
}

@test "malicious.html contains XSS patterns" {
    run grep "<script>" test/fixtures/poison/malicious.html
    [ "$status" -eq 0 ]

    run grep "onerror=" test/fixtures/poison/malicious.html
    [ "$status" -eq 0 ]

    run grep "javascript:" test/fixtures/poison/malicious.html
    [ "$status" -eq 0 ]
}

@test "semgrep detects prompt injection in CLAUDE.md" {
    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not installed"
    fi

    run semgrep scan \
        --config=.semgrep/claudebox-rules.yaml \
        --include="test/fixtures/poison/CLAUDE.md" \
        --error \
        --quiet

    # Should find at least 3 issues (prompt-injection-override, jailbreak-attempt, role-manipulation)
    [ "$status" -ne 0 ]
}

@test "semgrep detects malicious MCP commands" {
    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not installed"
    fi

    run semgrep scan \
        --config=.semgrep/claudebox-rules.yaml \
        --include="test/fixtures/poison/.mcp.json" \
        --error \
        --quiet

    # Should find multiple malicious-mcp-command issues
    [ "$status" -ne 0 ]
}

@test "semgrep detects template injection in Dockerfile" {
    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not installed"
    fi

    run semgrep scan \
        --config=.semgrep/claudebox-rules.yaml \
        --include="test/fixtures/poison/Dockerfile.template" \
        --error \
        --quiet

    # Should find template-command-injection, dangerous-permissions, path-traversal issues
    [ "$status" -ne 0 ]
}

@test "semgrep detects hidden unicode characters" {
    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not installed"
    fi

    run semgrep scan \
        --config=.semgrep/claudebox-rules.yaml \
        --include="test/fixtures/poison/hidden-unicode.md" \
        --error \
        --quiet

    # Should find hidden-unicode-characters issues
    [ "$status" -ne 0 ]
}

@test "semgrep detects encoded payloads" {
    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not installed"
    fi

    run semgrep scan \
        --config=.semgrep/claudebox-rules.yaml \
        --include="test/fixtures/poison/encoded-payload.sh" \
        --error \
        --quiet

    # Should find suspicious-encoded-content and regex-bypass-attempt issues
    [ "$status" -ne 0 ]
}

@test "semgrep detects XSS in markdown" {
    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not installed"
    fi

    run semgrep scan \
        --config=.semgrep/claudebox-rules.yaml \
        --include="test/fixtures/poison/malicious.html" \
        --error \
        --quiet

    # Should find html-script-in-markdown issues
    [ "$status" -ne 0 ]
}

@test "semgrep finds all poison patterns in full scan" {
    if ! command -v semgrep >/dev/null 2>&1; then
        skip "semgrep not installed"
    fi

    run semgrep scan \
        --config=.semgrep/claudebox-rules.yaml \
        test/fixtures/poison/ \
        --json \
        --output=./tmp/poison-scan-results.json

    [ "$status" -eq 1 ]  # Should exit 1 due to findings
    [ -f "./tmp/poison-scan-results.json" ]

    # Count findings
    FINDING_COUNT=$(jq '.results | length' ./tmp/poison-scan-results.json)
    printf "Found %d security issues in poison test cases\n" "$FINDING_COUNT" >&2

    # Should find at least 15 issues across all test files
    [ "$FINDING_COUNT" -ge 15 ]
}
