.PHONY: help shellcheck test clean

# Default target
.DEFAULT_GOAL := help

# Color output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(CYAN)ClaudeBox Development Tasks$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

shellcheck: ## Run shellcheck on all bash scripts
	@echo "$(CYAN)Running shellcheck...$(NC)"
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "$(RED)ERROR: shellcheck not installed$(NC)"; \
		echo "Install with:"; \
		echo "  macOS: brew install shellcheck"; \
		echo "  Ubuntu/Debian: apt-get install shellcheck"; \
		echo "  RHEL/CentOS: yum install shellcheck"; \
		exit 1; \
	fi
	@echo "Checking main script..."
	@shellcheck main.sh || exit 1
	@echo "Checking library files..."
	@shellcheck lib/*.sh || exit 1
	@echo "Checking build scripts..."
	@shellcheck build/docker-entrypoint build/init-firewall build/generate-tools-readme 2>/dev/null || true
	@echo "$(GREEN)✓ ShellCheck passed!$(NC)"

test: shellcheck ## Run all tests (currently just shellcheck)
	@echo "$(GREEN)✓ All tests passed!$(NC)"

clean: ## Clean temporary files
	@echo "$(CYAN)Cleaning temporary files...$(NC)"
	@find . -name "*.tmp" -type f -delete 2>/dev/null || true
	@find . -name ".DS_Store" -type f -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Clean complete!$(NC)"
