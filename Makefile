# Makefile for hd-map-asset-example
# Build command center for common development tasks

# Allow parent makefiles to override the venv path/tooling.
VENV ?= .venv

# Submodule path aliases (hide deep paths)
ASSET_TOOLS := submodules/sl-5-8-asset-tools
OMB         := $(ASSET_TOOLS)/submodules/ontology-management-base

# OS detection for cross-platform support (Windows vs Unix)
ifeq ($(OS),Windows_NT)
    VENV_BIN         := $(VENV)/Scripts
    PYTHON           ?= $(VENV_BIN)/python.exe
    BOOTSTRAP_PYTHON ?= python
else
    VENV_BIN         := $(VENV)/bin
    PYTHON           ?= $(VENV_BIN)/python3
    BOOTSTRAP_PYTHON ?= python3
endif
ACTIVATE_SCRIPT := $(VENV_BIN)/activate

# Asset metadata
ASSET_DIR := asset
METADATA  := $(ASSET_DIR)/metadata/hdmap_instance.json

# ── Subcommand support ───────────────────────────────────────────────
# Enables:  make asset zip
SUBCMD = $(word 2,$(MAKECMDGOALS))

# ── Guards ───────────────────────────────────────────────────────────
define check_dev_setup
	@if [ ! -f "$(PYTHON)" ]; then \
		echo ""; \
		echo "[ERR] Development environment not set up."; \
		echo "  Run:  make setup"; \
		echo ""; \
		exit 1; \
	fi
endef

.PHONY: all setup install lint format validate asset clean help

# Default target
all: lint validate

# ── Setup & Install ──────────────────────────────────────────────────

setup: $(ACTIVATE_SCRIPT)
	@if ! "$(PYTHON)" -c "import rdflib, pyshacl" >/dev/null 2>&1; then \
		echo "[INFO] Dependencies missing — reinstalling..."; \
		"$(PYTHON)" -m pip install -e "$(ASSET_TOOLS)[dev]"; \
		"$(PYTHON)" -m pip install -e "$(OMB)"; \
	fi
	@echo "[OK] Setup complete.  Activate with:  source $(ACTIVATE_SCRIPT)"

$(PYTHON):
	@echo "[INFO] Creating virtual environment at $(VENV)..."
	@"$(BOOTSTRAP_PYTHON)" -m venv "$(VENV)"
	@"$(PYTHON)" -m pip install --upgrade pip

$(ACTIVATE_SCRIPT): $(PYTHON)
	@echo "[INFO] Installing dependencies..."
	@"$(PYTHON)" -m pip install -e "$(ASSET_TOOLS)[dev]"
	@"$(PYTHON)" -m pip install -e "$(OMB)"
	@touch "$(ACTIVATE_SCRIPT)"

install:
	$(call check_dev_setup)
	@"$(PYTHON)" -m pip install -e "$(ASSET_TOOLS)"
	@"$(PYTHON)" -m pip install -e "$(OMB)"
	@echo "[OK] Install complete"

# ── Lint & Format ────────────────────────────────────────────────────
# Root repo has no Python files — lint validates JSON-LD asset data.

lint: validate

format:
	$(call check_dev_setup)
	@echo "[INFO] Nothing to format (no Python files in root repo)"

# ── Validate ─────────────────────────────────────────────────────────

validate:
	$(call check_dev_setup)
	@echo "[INFO] Validating asset JSON-LD against SHACL shapes..."
	@"$(PYTHON)" -m src.tools.validators.validation_suite \
		--run check-data-conformance \
		--data-paths $(ASSET_DIR)/manifest_reference.json $(METADATA) \
		--artifacts "$(OMB)/artifacts"
	@echo "[OK] Validation complete"

# ── Asset packaging ──────────────────────────────────────────────────

asset:
ifeq ($(SUBCMD),zip)
	$(call check_dev_setup)
	@echo "[INFO] Creating asset zip..."
	@ASSET_NAME=$$($(PYTHON) -c "import json; d=json.load(open('$(METADATA)')); print(d['hdmap:hasDataResource']['gx:name']['@value'].replace(' ', '_'))"); \
	cd $(ASSET_DIR) && zip -r "../$$ASSET_NAME.zip" ./*; \
	echo "[OK] Created $$ASSET_NAME.zip"
else
	@echo "[ERR] Unknown subcommand: $(SUBCMD)"
	@echo "Usage:  make asset zip"
	@exit 1
endif

# ── Clean ────────────────────────────────────────────────────────────

clean:
	@echo "[INFO] Cleaning..."
	@rm -rf build/ dist/ *.egg-info/ .pytest_cache/ .mypy_cache/
	@find . -path ./$(ASSET_TOOLS) -prune -o -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@rm -f *.zip
	@echo "[OK] Cleaned"

# ── Help ─────────────────────────────────────────────────────────────

help:
	@echo "hd-map-asset-example -- Available Commands"
	@echo ""
	@echo "  make setup              Create venv and install all dependencies"
	@echo "  make install            Install packages"
	@echo ""
	@echo "  make lint               Lint (validates asset JSON-LD)"
	@echo "  make validate           Validate asset JSON-LD against SHACL shapes"
	@echo ""
	@echo "  make asset zip          Create asset zip for release"
	@echo ""
	@echo "  make clean              Remove build artifacts and caches"

# ── Catch-all for subcommand arguments ───────────────────────────────
ifneq ($(filter asset,$(firstword $(MAKECMDGOALS))),)
%:
	@:
endif
