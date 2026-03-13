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
    ACTIVATE_SCRIPT  := $(VENV_BIN)/activate
    ACTIVATE_HINT    := use the activation script under $(VENV_BIN) for your shell
else
    VENV_BIN         := $(VENV)/bin
    PYTHON           ?= $(VENV_BIN)/python3
    BOOTSTRAP_PYTHON ?= python3
    ACTIVATE_SCRIPT  := $(VENV_BIN)/activate
    ACTIVATE_HINT    := source $(ACTIVATE_SCRIPT)
endif

# Generated asset directory
GENERATED_DIR := generated
GEN_INPUT     := $(GENERATED_DIR)/input
GEN_OUTPUT    := $(GENERATED_DIR)/output
GEN_CONFIGS   := $(ASSET_TOOLS)/configs

# ── Subcommand support ───────────────────────────────────────────────
# Enables:  make generate clean, make setup qc
SUBCMD = $(word 2,$(MAKECMDGOALS))

# ── Guards ───────────────────────────────────────────────────────────
define check_dev_setup
	@"$(PYTHON)" -c "True" 2>/dev/null || { \
		echo ""; \
		echo "[ERR] Development environment not set up."; \
		echo "  Run:  make setup"; \
		echo ""; \
		exit 1; \
	}
endef

.PHONY: all setup install lint format validate generate clean help

# Default target
all: lint validate

# ── Setup & Install ──────────────────────────────────────────────────

setup: $(ACTIVATE_SCRIPT)
ifeq ($(SUBCMD),qc)
	$(call check_dev_setup)
	@echo "[INFO] Installing quality checker runtime dependencies..."
	@"$(PYTHON)" -m pip install -e "$(ASSET_TOOLS)[qc-deps]" --quiet
	@echo "[INFO] Installing quality checker packages (--no-deps to avoid upstream lxml/numpy constraints)..."
	@"$(PYTHON)" -m pip install poetry-core --quiet 2>/dev/null || true
	@"$(PYTHON)" -m pip install --no-deps \
		"asam-qc-baselib@git+https://github.com/asam-ev/qc-baselib-py@main" \
		"asam-qc-opendrive@git+https://github.com/jdsika/qc-opendrive@fix-contact-point-missing-road-link" \
		"asam-qc-openscenarioxml@git+https://github.com/asam-ev/qc-openscenarioxml@main" \
		"openmsl-qc-opendrive@git+https://github.com/openMSL/sl-5-9-openmsl-qc-opendrive@main"
# NOTE: qc-opendrive is pinned to a fork pending upstream PR asam-ev/qc-opendrive#139.
# Switch back to @main once the PR is merged.
	@echo "[OK] Quality checkers installed"
else
	@"$(MAKE)" -C "$(ASSET_TOOLS)" setup VENV="$(CURDIR)/$(VENV)" PYTHON="$(CURDIR)/$(PYTHON)"
	@"$(PYTHON)" -m pre_commit install --allow-missing-config >/dev/null 2>&1 || true
	@echo "[OK] Setup complete. Activate with: $(ACTIVATE_HINT)"
endif

$(PYTHON):
	@echo "[INFO] Creating virtual environment at $(VENV)..."
	@"$(BOOTSTRAP_PYTHON)" -m venv "$(VENV)"
	@"$(PYTHON)" -m pip install --upgrade pip

$(ACTIVATE_SCRIPT): $(PYTHON)
	@"$(MAKE)" -C "$(ASSET_TOOLS)" setup VENV="$(CURDIR)/$(VENV)" PYTHON="$(CURDIR)/$(PYTHON)"
	@touch "$(ACTIVATE_SCRIPT)"

install:
	$(call check_dev_setup)
	@"$(MAKE)" -C "$(ASSET_TOOLS)" install VENV="$(CURDIR)/$(VENV)" PYTHON="$(CURDIR)/$(PYTHON)"
	@echo "[OK] Install complete"

# ── Lint & Format ────────────────────────────────────────────────────
# Root repo has no Python files — lint validates JSON-LD asset data.

lint: validate

format:
	$(call check_dev_setup)
	@echo "[INFO] Nothing to format (no Python files in root repo)"

# ── Validate ─────────────────────────────────────────────────────────
# Validates JSON-LD files for every generated asset in the output directory.

validate:
ifneq ($(firstword $(MAKECMDGOALS)),generate)
	$(call check_dev_setup)
	@"$(PYTHON)" -c "\
import pathlib, sys; \
out = pathlib.Path('$(GEN_OUTPUT)'); \
dirs = sorted(d for d in out.iterdir() if d.is_dir()) if out.exists() else []; \
sys.exit('[SKIP] No generated asset found (run: make generate)') if not dirs else None; \
bad = [str(d) for d in dirs if not [p for p in [d / 'manifest.json', d / 'metadata' / 'hdmap.json'] if p.exists()]]; \
sys.exit('[ERR] No manifest or metadata found in: ' + ', '.join(bad)) if bad else None; \
all_paths = [str(p) for d in dirs for p in [d / 'manifest.json', d / 'metadata' / 'hdmap.json'] if p.exists()]; \
print(' '.join(all_paths)); \
" > .validate_paths 2>&1 && \
	"$(PYTHON)" -m src.tools.validators.validation_suite \
		--run check-data-conformance \
		--data-paths $$(cat .validate_paths) \
		--artifacts "$(OMB)/artifacts" && \
	rm -f .validate_paths && \
	echo "[OK] Validation complete" || \
	{ cat .validate_paths 2>/dev/null; rm -f .validate_paths; exit 1; }
endif

# ── Generate (full pipeline) ─────────────────────────────────────────

generate:
ifeq ($(SUBCMD),clean)
	@echo "[INFO] Removing generated/output/ directory..."
	@"$(PYTHON)" -c "import shutil; shutil.rmtree('$(GEN_OUTPUT)', ignore_errors=True)"
	@echo "[OK] Generated output removed (input/ blueprint preserved)"
else ifeq ($(SUBCMD),validate)
	@"$(MAKE)" validate
else
	$(call check_dev_setup)
	@"$(PYTHON)" -c "\
import pathlib, sys; \
im = pathlib.Path('$(GEN_INPUT)') / 'input_manifest.json'; \
sys.exit('[ERR] No input_manifest.json in $(GEN_INPUT)/. Stage input files first.') if not im.exists() else None; \
"
	@mkdir -p "$(GEN_OUTPUT)" 2>/dev/null || "$(PYTHON)" -c "import pathlib; pathlib.Path('$(GEN_OUTPUT)').mkdir(parents=True, exist_ok=True)"
	@echo "[INFO] Running asset creation pipeline..."
	@cd "$(GEN_INPUT)" && "$(CURDIR)/$(PYTHON)" -m asset_extraction.main \
		input_manifest.json \
		-config "$(CURDIR)/$(GEN_CONFIGS)" \
		-out "$(CURDIR)/$(GEN_OUTPUT)"
	@echo ""
	@echo "[OK] Asset generated in $(GEN_OUTPUT)/"
endif

# ── Clean ────────────────────────────────────────────────────────────

clean:
ifneq ($(firstword $(MAKECMDGOALS)),generate)
	@echo "[INFO] Cleaning..."
	@rm -rf build/ dist/ .pytest_cache/ .mypy_cache/ "$(GENERATED_DIR)"
	@find . -maxdepth 3 -type d -name __pycache__ -not -path "*/$(ASSET_TOOLS)/*" -exec rm -rf {} + 2>/dev/null || true
	@find . -maxdepth 1 -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@rm -f *.zip
	@echo "[OK] Cleaned"
endif

# ── Help ─────────────────────────────────────────────────────────────

help:
	@echo "hd-map-asset-example -- Available Commands"
	@echo ""
	@echo "  make setup                   Create venv and install all dependencies"
	@echo "  make setup qc                Also install quality checker tools (optional, slow)"
	@echo "  make install                 Install packages"
	@echo ""
	@echo "  make generate                Run full pipeline: .xodr -> generated/ asset + zip"
	@echo "  make generate validate       Validate the generated asset"
	@echo "  make generate clean          Remove generated/output/ directory"
	@echo ""
	@echo "  make lint                    Lint (validates asset JSON-LD)"
	@echo "  make validate                Validate generated/output/ asset against SHACL"
	@echo ""
	@echo "  make clean                   Remove all build artifacts, caches, and generated/"
	@echo ""
	@echo "Debug logging:"
	@echo "  SL58_LOG_MODE=debug make generate"
	@echo "  Shows full subprocess command lines, stdout/stderr, and tracebacks."
	@echo ""
	@echo "Deterministic mode (reproducible output):"
	@echo "  SL58_DETERMINISTIC=1 make generate"
	@echo "  Same input files produce identical UUIDs, timestamps, and CID."

# ── Catch-all for subcommand arguments ───────────────────────────────
ifneq ($(filter setup generate,$(firstword $(MAKECMDGOALS))),)
%:
	@:
endif
