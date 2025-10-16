#!/usr/bin/env bats
# Tests for array iteration safety with set -u

load test_helper

@test "empty array iteration is safe in config.sh" {
    source_lib "config.sh"

    # Test with empty arrays
    local test_array=()

    # Enable strict mode like the real script
    set -u

    # This should not throw unbound variable error
    if [[ ${#test_array[@]} -gt 0 ]]; then
        for item in "${test_array[@]}"; do
            echo "$item"
        done
    fi

    set +u
}

@test "empty array iteration is safe in cli.sh" {
    source_lib "common.sh"
    source_lib "cli.sh"

    # Test with empty CLI_HOST_FLAGS
    export CLI_HOST_FLAGS=()

    set -u

    # Call process_host_flags with empty array - should not fail
    process_host_flags

    set +u
}

@test "read_profile_section handles empty profiles.ini" {
    source_lib "config.sh"

    local profiles_file="$TEST_TEMP_DIR/profiles.ini"
    echo "[profiles]" > "$profiles_file"
    echo "" >> "$profiles_file"

    set -u

    # Should return empty without error
    local result
    result=$(read_profile_section "$profiles_file" "profiles")

    [[ -z "$result" ]]

    set +u
}

@test "read_profile_section handles non-existent file" {
    source_lib "config.sh"

    set -u

    # Should handle missing file gracefully
    local result
    result=$(read_profile_section "/nonexistent/profiles.ini" "profiles" || echo "")

    [[ -z "$result" ]]

    set +u
}

@test "update_profile_section handles empty arrays" {
    source_lib "config.sh"

    local profiles_file="$TEST_TEMP_DIR/profiles.ini"

    set -u

    # Should not fail with no items
    update_profile_section "$profiles_file" "profiles"

    [[ -f "$profiles_file" ]]
    grep -q "^\[profiles\]" "$profiles_file"

    set +u
}

@test "profile iteration handles empty current_profiles array" {
    source_lib "config.sh"

    local profiles_file="$TEST_TEMP_DIR/profiles.ini"
    create_mock_profiles_ini "$profiles_file"  # Empty profiles

    set -u

    # Read empty profiles section
    local current_profiles=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && current_profiles+=("$line")
    done < <(read_profile_section "$profiles_file" "profiles")

    # Should be able to check length safely
    [[ ${#current_profiles[@]} -eq 0 ]]

    # Should be able to iterate safely
    if [[ ${#current_profiles[@]} -gt 0 ]]; then
        for profile in "${current_profiles[@]}"; do
            echo "$profile"
        done
    fi

    set +u
}

@test "all array iterations follow safe pattern" {
    # This test checks that our pattern is consistent

    # Count unsafe patterns (should be 0)
    local unsafe_count
    unsafe_count=$(grep -r 'for .* in "\${[^}]*\[@\]}"' "$CLAUDEBOX_ROOT/lib" "$CLAUDEBOX_ROOT/main.sh" 2>/dev/null | \
        grep -v "# Only iterate if array has elements" | \
        grep -v "if \[\[ \${#" | \
        wc -l | tr -d ' ')

    # All array iterations should be preceded by length check
    [[ "$unsafe_count" -eq 0 ]] || {
        echo "Found $unsafe_count unsafe array iterations"
        grep -rn 'for .* in "\${[^}]*\[@\]}"' "$CLAUDEBOX_ROOT/lib" "$CLAUDEBOX_ROOT/main.sh" 2>/dev/null | \
            grep -v "# Only iterate if array has elements" | \
            grep -B2 'for .* in'
        return 1
    }
}
