#!/usr/bin/env bash
# Test fixture with intentional ShellCheck violations
# This file should NEVER be executed - it's for testing security scanners

# SC2086: Unquoted variable (command injection risk)
dangerous_unquoted() {
    local user_input=$1
    # shellcheck disable=SC2086
    docker run $user_input claudebox
}

# SC2294: eval with variable (code injection risk)
dangerous_eval() {
    local command=$1
    # shellcheck disable=SC2294
    eval "$command"
}

# SC2046: Unquoted command substitution
dangerous_substitution() {
    # shellcheck disable=SC2046,SC2006
    local files=$(ls *.txt)
    # shellcheck disable=SC2086
    rm $files
}

# SC2006: Legacy backtick usage
dangerous_backticks() {
    # shellcheck disable=SC2006
    result=`grep pattern file`
    # shellcheck disable=SC2086
    echo $result
}

# Test that scanner detects these issues
printf "This file contains intentional security vulnerabilities for testing\n"
