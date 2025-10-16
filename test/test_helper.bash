#!/usr/bin/env bash
# Test helper functions for ClaudeBox Bats tests

# Get the root directory of the project
# shellcheck disable=SC2154
export CLAUDEBOX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export LIB_DIR="${CLAUDEBOX_ROOT}/lib"

# Source library files for testing
source_lib() {
    local lib_file="$1"
    # shellcheck disable=SC1090
    source "${LIB_DIR}/${lib_file}"
}

# Setup function called before each test
setup() {
    # Create temporary directory for tests
    export TEST_TEMP_DIR="$(mktemp -d)"
    export HOME="${TEST_TEMP_DIR}"
    export PROJECT_DIR="${TEST_TEMP_DIR}/test-project"
    mkdir -p "${PROJECT_DIR}"
}

# Teardown function called after each test
teardown() {
    # Clean up temporary directory
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Helper to check if a function exists
function_exists() {
    declare -f "$1" > /dev/null
    return $?
}

# Helper to create a mock profiles.ini file
create_mock_profiles_ini() {
    local profiles_file="$1"
    shift
    local profiles=("$@")

    mkdir -p "$(dirname "${profiles_file}")"
    {
        echo "[profiles]"
        if [[ ${#profiles[@]} -gt 0 ]]; then
            for profile in "${profiles[@]}"; do
                echo "${profile}"
            done
        fi
        echo ""
    } > "${profiles_file}"
}

# Helper to verify array is safe to iterate with set -u
test_array_iteration_safe() {
    local array_name="$1"

    # Enable strict mode
    set -u

    # Try to iterate - this should not fail even if array is empty
    eval "
        if [[ \${#${array_name}[@]} -gt 0 ]]; then
            for item in \"\${${array_name}[@]}\"; do
                :
            done
        fi
    "

    # Disable strict mode
    set +u

    return 0
}
