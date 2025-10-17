.PHONY: help shellcheck test test-bats test-security test-poison test-all clean install-hooks

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

test-bats: ## Run Bats tests
	@echo "$(CYAN)Running Bats tests...$(NC)"
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "$(RED)ERROR: bats not installed$(NC)"; \
		echo "Install with:"; \
		echo "  macOS: brew install bats-core"; \
		echo "  Ubuntu/Debian: apt-get install bats"; \
		exit 1; \
	fi
	@bats test/*.bats || exit 1
	@echo "$(GREEN)✓ Bats tests passed!$(NC)"

test-security: ## Run security scanning tests only
	@echo "$(CYAN)Running security scanning tests...$(NC)"
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "$(RED)ERROR: bats not installed$(NC)"; \
		echo "Install with:"; \
		echo "  macOS: brew install bats-core"; \
		echo "  Ubuntu/Debian: apt-get install bats"; \
		exit 1; \
	fi
	@bats test/security_scanning.bats || exit 1
	@echo "$(GREEN)✓ Security tests passed!$(NC)"

test-poison: ## Run poison detection tests
	@echo "$(CYAN)Running poison detection tests...$(NC)"
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "$(RED)ERROR: bats not installed$(NC)"; \
		echo "Install with:"; \
		echo "  macOS: brew install bats-core"; \
		echo "  Ubuntu/Debian: apt-get install bats"; \
		exit 1; \
	fi
	@bats test/poison_detection.bats || exit 1
	@echo "$(GREEN)✓ Poison detection tests passed!$(NC)"

test: shellcheck ## Run shellcheck only (fast)
	@echo "$(GREEN)✓ ShellCheck passed!$(NC)"

test-all: shellcheck test-bats ## Run all tests (shellcheck + bats)
	@echo "$(GREEN)✓ All tests passed!$(NC)"

install-hooks: ## Install pre-commit hooks
	@echo "$(CYAN)Installing pre-commit hooks...$(NC)"
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "$(RED)ERROR: pre-commit not installed$(NC)"; \
		echo "Install with:"; \
		echo "  pip install pre-commit"; \
		echo "  or: brew install pre-commit"; \
		exit 1; \
	fi
	@pre-commit install
	@echo "$(GREEN)✓ Pre-commit hooks installed!$(NC)"
	@echo "Run manually with: pre-commit run --all-files"

clean: ## Clean temporary files
	@echo "$(CYAN)Cleaning temporary files...$(NC)"
	@find . -name "*.tmp" -type f -delete 2>/dev/null || true
	@find . -name ".DS_Store" -type f -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Clean complete!$(NC)"
