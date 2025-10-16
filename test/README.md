# ClaudeBox Testing

This directory contains the test suite for ClaudeBox using Bats (Bash Automated Testing System).

## Quick Start

```bash
# Install dependencies
brew install bats-core shellcheck pre-commit  # macOS
# or
apt-get install bats shellcheck && pip install pre-commit  # Linux

# Install pre-commit hooks
make install-hooks

# Run tests
make test          # ShellCheck only (fast)
make test-bats     # Bats tests only
make test-all      # Everything
```

## Test Structure

```
test/
├── README.md              # This file
├── test_helper.bash       # Shared test utilities
├── array_safety.bats      # Tests for array iteration safety (set -u compatibility)
└── config_functions.bats  # Tests for config.sh functions
```

## Writing Tests

Tests use Bats syntax:

```bash
@test "description of test" {
    # Test code here
    run some_command
    [ "$status" -eq 0 ]
    [[ "$output" == "expected" ]]
}
```

### Using test_helper.bash

The test helper provides:

- `source_lib "filename.sh"` - Source library files
- `setup()` / `teardown()` - Automatic test isolation
- `create_mock_profiles_ini()` - Create test profile files
- `TEST_TEMP_DIR` - Temporary directory for each test

### Testing Array Safety

Our tests verify that array iterations are safe with `set -u`:

```bash
@test "empty array is safe" {
    local my_array=()

    set -u  # Enable strict mode

    # This pattern is safe
    if [[ ${#my_array[@]} -gt 0 ]]; then
        for item in "${my_array[@]}"; do
            echo "$item"
        done
    fi

    set +u
}
```

## Pre-commit Hooks

Pre-commit runs automatically on `git commit` and checks:

1. **ShellCheck** - Bash linting for all `.sh` files
2. **Bats Tests** - Run test suite (if bats installed)
3. **YAML/JSON** - Validate configuration files
4. **Whitespace** - Trim trailing whitespace

### Manual Runs

```bash
# Run on all files
pre-commit run --all-files

# Run specific hook
pre-commit run shellcheck --all-files
pre-commit run bats --all-files

# Skip hooks for emergency commits
git commit --no-verify
```

## CI Integration

Add to `.github/workflows/test.yml`:

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck bats
      - name: Run tests
        run: make test-all
```

## Debugging Tests

```bash
# Run specific test file
bats test/array_safety.bats

# Run with verbose output
bats -t test/array_safety.bats

# Run single test
bats -f "empty array" test/array_safety.bats
```

## Coverage Goals

- ✅ Array iteration safety (Bash 3.2 + set -u)
- ✅ Config file parsing and manipulation
- 🚧 Profile management functions
- 🚧 Docker operations (mocked)
- 🚧 CLI argument parsing
- 🚧 Slot management

## Notes

- Tests run in isolated `$TEST_TEMP_DIR`
- Each test gets fresh `setup()` / `teardown()`
- Docker commands are NOT run in tests (use mocks)
- Tests must pass with Bash 3.2 compatibility
