#!/usr/bin/env bash
# Info Commands - Information display
# ============================================================================
# Commands: info, projects, allowlist, show-context
# Shows system, project, and configuration information

_cmd_projects() {
    cecho "ClaudeBox Projects:" "$CYAN"
    echo
    printf "%10s  %s  %s\n" "Size" "🐳" "Path"
    printf "%10s  %s  %s\n" "----" "--" "----"

    if ! list_all_projects; then
        echo
        warn "No ClaudeBox projects found."
        echo
        cecho "Start a new project:" "$GREEN"
        echo "  cd /your/project/directory"
        echo "  claudebox"
    fi
    echo
    exit 0
}

_cmd_allowlist() {
    # Allowlist is stored in parent directory, not slot directory
    local allowlist_file="$PROJECT_PARENT_DIR/allowlist"

    cecho "🔒 ClaudeBox Firewall Allowlist" "$CYAN"
    echo
    cecho "Current Project: $PROJECT_DIR" "$WHITE"
    echo

    if [[ -f "$allowlist_file" ]]; then
        cecho "Allowlist file:" "$GREEN"
        echo "  $allowlist_file"
        echo
        cecho "Allowed domains:" "$CYAN"
        # Display allowlist contents
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^#.* ]]; then
                echo "  $line"
            fi
        done < "$allowlist_file"
        echo
    else
        cecho "Allowlist file:" "$YELLOW"
        echo "  Not yet created (will be created on first run)"
        echo "  Location: $allowlist_file"
    fi

    echo
    cecho "Default Allowed Domains:" "$CYAN"
    echo "  api.anthropic.com, console.anthropic.com, statsig.anthropic.com, sentry.io"
    echo
    cecho "To edit allowlist:" "$YELLOW"
    echo "  \$EDITOR $allowlist_file"
    echo
    cecho "Note:" "$WHITE"
    echo "  Changes take effect on next container start"
    echo "  Use --disable-firewall flag to bypass all restrictions"

    exit 0
}

_cmd_info() {
    # Compute project folder name early for paths
    local project_folder_name
    project_folder_name=$(get_project_folder_name "$PROJECT_DIR")
    IMAGE_NAME="claudebox-${project_folder_name}"
    PROJECT_SLOT_DIR="$HOME/.claudebox/projects/$project_folder_name"

    cecho "╔═══════════════════════════════════════════════════════════════════╗" "$CYAN"
    cecho "║                    ClaudeBox Information Panel                    ║" "$CYAN"
    cecho "╚═══════════════════════════════════════════════════════════════════╝" "$CYAN"
    echo

    # Current Project Info
    cecho "📁 Current Project" "$WHITE"
    echo "   Path:       $PROJECT_DIR"
    echo "   Project ID: $project_folder_name"
    echo "   Data Dir:   $PROJECT_SLOT_DIR"
    echo

    # ClaudeBox Installation
    cecho "📦 ClaudeBox Installation" "$WHITE"
    echo "   Script:  $SCRIPT_PATH"
    echo "   Symlink: $LINK_TARGET"
    echo

    # Saved CLI Flags
    cecho "🚀 Saved CLI Flags" "$WHITE"
    if [[ -f "$HOME/.claudebox/default-flags" ]]; then
        local saved_flags=()
        while IFS= read -r flag; do
            [[ -n "$flag" ]] && saved_flags+=("$flag")
        done < "$HOME/.claudebox/default-flags"
        if [[ ${#saved_flags[@]} -gt 0 ]]; then
            echo -e "   Flags: ${GREEN}${saved_flags[*]}${NC}"
        else
            echo -e "   ${YELLOW}No flags saved${NC}"
        fi
    else
        echo -e "   ${YELLOW}No saved flags${NC}"
    fi
    echo

    # Claude Commands
    cecho "📝 Claude Commands" "$WHITE"
    local cmd_count=0
    if [[ -d "$HOME/.claude/commands" ]]; then
        cmd_count=$(ls -1 "$HOME/.claude/commands"/*.md 2>/dev/null | wc -l)
    fi
    local project_cmd_count=0
    if [[ -e "$PROJECT_PARENT_DIR/commands" ]]; then
        project_cmd_count=$(ls -1 "$PROJECT_PARENT_DIR/commands"/*.md 2>/dev/null | wc -l)
    fi

    if [[ $cmd_count -gt 0 ]] || [[ $project_cmd_count -gt 0 ]]; then
        echo "   Host:    $cmd_count command(s)"
        if [[ $cmd_count -gt 0 ]] && [[ -d "$HOME/.claude/commands" ]]; then
            for cmd_file in "$HOME/.claude/commands"/*.md; do
                [[ -f "$cmd_file" ]] || continue
                echo "            - $(basename "$cmd_file" .md)"
            done
        fi
        echo "   Project: $project_cmd_count command(s) (shared)"
        if [[ $project_cmd_count -gt 0 ]] && [[ -e "$PROJECT_PARENT_DIR/commands" ]]; then
            for cmd_file in "$PROJECT_PARENT_DIR/commands"/*.md; do
                [[ -f "$cmd_file" ]] || continue
                echo "            - $(basename "$cmd_file" .md)"
            done
        fi
    else
        echo -e "   ${YELLOW}No custom commands found${NC}"
        echo -e "   Location: ~/.claude/commands/ (host), project/commands/ (shared)"
    fi
    echo

    # Project Profiles
    cecho "🛠️ Project Profiles & Packages" "$WHITE"
    local current_profile_file
    current_profile_file=$(get_profile_file_path)
    if [[ -f "$current_profile_file" ]]; then
        local current_profiles=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_profiles+=("$line")
        done < <(read_profile_section "$current_profile_file" "profiles")
        local current_packages=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_packages+=("$line")
        done < <(read_profile_section "$current_profile_file" "packages")

        if [[ ${#current_profiles[@]} -gt 0 ]]; then
            echo -e "   Installed:  ${GREEN}${current_profiles[*]}${NC}"
        else
            echo -e "   Installed:  ${YELLOW}None${NC}"
        fi

        if [[ ${#current_packages[@]} -gt 0 ]]; then
            echo "   Packages:   ${current_packages[*]}"
        fi
    else
        echo -e "   Status:     ${YELLOW}No profiles installed${NC}"
    fi

    echo -e "   Available:  ${CYAN}core${NC}, python, c, rust, go, flutter, javascript, java, ruby, php"
    echo -e "               database, devops, web, ml, security, embedded, networking"
    echo -e "   ${CYAN}Hint:${NC} Run 'claudebox profile' for profile help "
    echo

    cecho "🐳 Docker Status" "$WHITE"
    if [[ -n "${IMAGE_NAME:-}" ]] && docker image inspect "$IMAGE_NAME" &>/dev/null; then
        local image_info=$(docker images --filter "reference=$IMAGE_NAME" --format "{{.Size}}")
        echo -e "   Image:      ${GREEN}Ready${NC} ($IMAGE_NAME - $image_info)"

        local image_created=$(docker inspect "$IMAGE_NAME" --format '{{.Created}}' | cut -d'T' -f1)
        local layer_count=$(docker history "$IMAGE_NAME" --no-trunc --format "{{.CreatedBy}}" | wc -l)
        echo "   Created:    $image_created"
        echo "   Layers:     $layer_count"
    else
        echo -e "   Image:      ${YELLOW}Not built${NC}"
    fi

    local running_containers=$(docker ps --filter "ancestor=$IMAGE_NAME" -q 2>/dev/null)
    if [[ -n "$running_containers" ]]; then
        local container_count=$(echo "$running_containers" | wc -l)
        echo -e "   Containers: ${GREEN}$container_count running${NC}"

        for container_id in $running_containers; do
            local container_stats="$(docker stats --no-stream --format "{{.Container}}: {{.CPUPerc}} CPU, {{.MemUsage}}" "$container_id" 2>/dev/null || echo "")"
            if [[ -n "$container_stats" ]]; then
                echo "               - $container_stats"
            fi
        done
    else
        echo "   Containers: None running"
    fi
    echo

    # All Projects Summary
    cecho "📊 All Projects Summary" "$WHITE"
    local total_projects=$(ls -1d "$HOME/.claudebox/projects"/*/ 2>/dev/null | wc -l)
    echo "   Projects:   $total_projects total"

    local total_size=$(docker images --filter "reference=claudebox-*" --format "{{.Size}}" | awk '{
        size=$1; unit=$2;
        if (unit == "GB") size = size * 1024;
        else if (unit == "KB") size = size / 1024;
        total += size
    } END {
        if (total > 1024) printf "%.1fGB", total/1024;
        else printf "%.1fMB", total
    }')
    local image_count=$(docker images --filter "reference=claudebox-*" -q | wc -l)
    echo "   Images:     $image_count ClaudeBox images using $total_size"

    local docker_stats=$(docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" 2>/dev/null | tail -n +2)
    if [[ -n "$docker_stats" ]]; then
        echo "   System:"
        while IFS=$'\t' read -r type total active size reclaim; do
            echo "               - $type: $total total, $active active ($size, $reclaim reclaimable)"
        done <<< "$docker_stats"
    fi
    echo

    exit 0
}

_cmd_show_context() {
    cecho "╔═══════════════════════════════════════════════════════════════════╗" "$CYAN"
    cecho "║           ClaudeBox Context & Template Security Audit            ║" "$CYAN"
    cecho "╚═══════════════════════════════════════════════════════════════════╝" "$CYAN"
    echo

    cecho "🔍 Context Sources" "$WHITE"
    echo "   ClaudeBox loads context from these locations:"
    echo

    # Global CLAUDE.md
    if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
        local size=$(du -h "$HOME/.claude/CLAUDE.md" | cut -f1)
        local lines=$(wc -l < "$HOME/.claude/CLAUDE.md")
        printf "   ${GREEN}✓${NC} Global:  %s (%s, %d lines)\n" "$HOME/.claude/CLAUDE.md" "$size" "$lines"
    else
        printf "   ${YELLOW}✗${NC} Global:  %s (not found)\n" "$HOME/.claude/CLAUDE.md"
    fi

    # Project CLAUDE.md
    if [[ -f "$PROJECT_DIR/CLAUDE.md" ]]; then
        local size=$(du -h "$PROJECT_DIR/CLAUDE.md" | cut -f1)
        local lines=$(wc -l < "$PROJECT_DIR/CLAUDE.md")
        printf "   ${GREEN}✓${NC} Project: %s (%s, %d lines)\n" "$PROJECT_DIR/CLAUDE.md" "$size" "$lines"
    else
        printf "   ${YELLOW}✗${NC} Project: %s (not found)\n" "$PROJECT_DIR/CLAUDE.md"
    fi
    echo

    # MCP Configuration
    cecho "🔌 MCP Server Configuration" "$WHITE"
    local found_mcp=false
    if [[ -f "$HOME/.claude/.mcp.json" ]]; then
        printf "   ${GREEN}✓${NC} Global:  %s\n" "$HOME/.claude/.mcp.json"
        found_mcp=true
    fi
    if [[ -f "$PROJECT_DIR/.mcp.json" ]]; then
        printf "   ${GREEN}✓${NC} Project: %s\n" "$PROJECT_DIR/.mcp.json"
        found_mcp=true
    fi
    if [[ "$found_mcp" == "false" ]]; then
        echo "   No MCP configurations found"
    fi
    echo

    # Dockerfile Templates
    cecho "📝 Docker Templates" "$WHITE"
    local template_dir="$SCRIPT_DIR/build"
    if [[ -f "$template_dir/Dockerfile" ]]; then
        local lines=$(wc -l < "$template_dir/Dockerfile" 2>/dev/null || echo "0")
        printf "   ${GREEN}✓${NC} Base:    %s (%d lines)\n" "$template_dir/Dockerfile" "$lines"
    fi
    if [[ -f "$template_dir/Dockerfile.project" ]]; then
        local lines=$(wc -l < "$template_dir/Dockerfile.project" 2>/dev/null || echo "0")
        printf "   ${GREEN}✓${NC} Project: %s (%d lines)\n" "$template_dir/Dockerfile.project" "$lines"
    fi
    echo

    # Custom Commands
    cecho "⚙️  Custom Commands" "$WHITE"
    local cmd_count=0
    if [[ -d "$HOME/.claude/commands" ]]; then
        cmd_count=$(ls -1 "$HOME/.claude/commands"/*.md 2>/dev/null | wc -l)
    fi
    local project_cmd_count=0
    if [[ -e "$PROJECT_PARENT_DIR/commands" ]]; then
        project_cmd_count=$(ls -1 "$PROJECT_PARENT_DIR/commands"/*.md 2>/dev/null | wc -l)
    fi

    if [[ $cmd_count -gt 0 ]] || [[ $project_cmd_count -gt 0 ]]; then
        printf "   Host:    %d command(s) in ~/.claude/commands/\n" "$cmd_count"
        printf "   Project: %d command(s) in project/commands/\n" "$project_cmd_count"
    else
        echo "   No custom commands found"
    fi
    echo

    # Security Scanning Status
    cecho "🔒 Security Scanning" "$WHITE"

    # Check for Semgrep
    if command -v semgrep >/dev/null 2>&1; then
        printf "   ${GREEN}✓${NC} Semgrep: Installed (context poisoning detection)\n"

        # Run Semgrep scan on context files
        local scan_files=()
        [[ -f "$HOME/.claude/CLAUDE.md" ]] && scan_files+=("$HOME/.claude/CLAUDE.md")
        [[ -f "$PROJECT_DIR/CLAUDE.md" ]] && scan_files+=("$PROJECT_DIR/CLAUDE.md")
        [[ -f "$HOME/.claude/.mcp.json" ]] && scan_files+=("$HOME/.claude/.mcp.json")
        [[ -f "$PROJECT_DIR/.mcp.json" ]] && scan_files+=("$PROJECT_DIR/.mcp.json")

        if [[ ${#scan_files[@]} -gt 0 ]]; then
            echo "   Running scan on context files..."

            # Run semgrep
            local scan_result=0
            if semgrep scan \
                --config=.semgrep/claudebox-rules.yaml \
                --quiet \
                "${scan_files[@]}" >/dev/null 2>&1; then
                scan_result=$?
            else
                scan_result=$?
            fi

            if [[ $scan_result -eq 0 ]]; then
                printf "   ${GREEN}✓${NC} No security issues detected\n"
            else
                printf "   ${YELLOW}⚠${NC}  Security issues found - run 'semgrep scan --config=.semgrep/claudebox-rules.yaml' for details\n"
            fi
        fi
    else
        printf "   ${YELLOW}✗${NC} Semgrep: Not installed\n"
        echo "             Install: pip install semgrep"
    fi

    # Check for TruffleHog
    if command -v trufflehog >/dev/null 2>&1; then
        printf "   ${GREEN}✓${NC} TruffleHog: Installed (secret detection)\n"
    else
        printf "   ${YELLOW}✗${NC} TruffleHog: Not installed\n"
    fi

    # Check for detect-secrets
    if command -v detect-secrets >/dev/null 2>&1; then
        printf "   ${GREEN}✓${NC} detect-secrets: Installed\n"
    else
        printf "   ${YELLOW}✗${NC} detect-secrets: Not installed\n"
    fi
    echo

    # Security Best Practices
    cecho "💡 Security Best Practices" "$WHITE"
    echo "   • Review CLAUDE.md files for suspicious instructions"
    echo "   • Verify MCP server commands don't execute untrusted code"
    echo "   • Check for hidden unicode characters in context files"
    echo "   • Run security scans regularly: 'semgrep scan --config=.semgrep/claudebox-rules.yaml'"
    echo "   • Inspect Docker templates before building: '$template_dir/Dockerfile'"
    echo

    cecho "📚 More Information" "$WHITE"
    echo "   Security Policy: https://github.com/bdmorin/claudebox/blob/main/SECURITY.md"
    echo "   Semgrep Rules:   .semgrep/claudebox-rules.yaml"
    echo "   Pre-commit:      .pre-commit-config.yaml"
    echo

    exit 0
}

export -f _cmd_projects _cmd_allowlist _cmd_info _cmd_show_context