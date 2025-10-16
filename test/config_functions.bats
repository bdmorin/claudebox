#!/usr/bin/env bats
# Tests for config.sh functions

load test_helper

@test "get_profile_packages returns packages for core profile" {
    source_lib "config.sh"

    local packages
    packages=$(get_profile_packages "core")

    [[ -n "$packages" ]]
    [[ "$packages" == *"gcc"* ]]
    [[ "$packages" == *"git"* ]]
}

@test "get_profile_packages returns empty for unknown profile" {
    source_lib "config.sh"

    local packages
    packages=$(get_profile_packages "nonexistent")

    [[ -z "$packages" ]]
}

@test "profile_exists returns 0 for valid profile" {
    source_lib "config.sh"

    profile_exists "python"
}

@test "profile_exists returns 1 for invalid profile" {
    source_lib "config.sh"

    run profile_exists "nonexistent"

    [[ "$status" -ne 0 ]]
}

@test "expand_profile includes dependencies" {
    source_lib "config.sh"

    local expanded
    expanded=$(expand_profile "c")

    [[ "$expanded" == *"core"* ]]
    [[ "$expanded" == *"build-tools"* ]]
}

@test "read_profile_section extracts profiles correctly" {
    source_lib "config.sh"

    local profiles_file="$TEST_TEMP_DIR/profiles.ini"
    create_mock_profiles_ini "$profiles_file" "python" "rust" "go"

    local profiles
    profiles=$(read_profile_section "$profiles_file" "profiles")

    echo "$profiles" | grep -q "python"
    echo "$profiles" | grep -q "rust"
    echo "$profiles" | grep -q "go"
}

@test "update_profile_section creates new section" {
    source_lib "config.sh"

    local profiles_file="$TEST_TEMP_DIR/profiles.ini"

    update_profile_section "$profiles_file" "profiles" "python" "rust"

    [[ -f "$profiles_file" ]]

    local content
    content=$(cat "$profiles_file")

    echo "$content" | grep -q "^\[profiles\]"
    echo "$content" | grep -q "^python$"
    echo "$content" | grep -q "^rust$"
}

@test "update_profile_section prevents duplicates" {
    source_lib "config.sh"

    local profiles_file="$TEST_TEMP_DIR/profiles.ini"

    # Add python twice
    update_profile_section "$profiles_file" "profiles" "python"
    update_profile_section "$profiles_file" "profiles" "python"

    # Should only appear once
    local count
    count=$(grep -c "^python$" "$profiles_file")

    [[ "$count" -eq 1 ]]
}
