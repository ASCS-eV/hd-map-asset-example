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

# Generated asset directory
GENERATED_DIR := generated
GEN_INPUT     := $(GENERATED_DIR)/input
GEN_OUTPUT    := $(GENERATED_DIR)/output
GEN_CONFIGS   := $(ASSET_TOOLS)/configs

# ── Subcommand support ───────────────────────────────────────────────
# Enables:  make asset zip, make generate clean, make setup qc
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

.PHONY: all setup install lint format validate asset generate clean help

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
		"asam-qc-opendrive@git+https://github.com/asam-ev/qc-opendrive@main" \
		"asam-qc-openscenarioxml@git+https://github.com/asam-ev/qc-openscenarioxml@main" \
		"openmsl-qc-opendrive@git+https://github.com/openMSL/sl-5-9-openmsl-qc-opendrive@main"
	@echo "[OK] Quality checkers installed"
else
	@$(MAKE) -C "$(ASSET_TOOLS)" setup VENV="$(CURDIR)/$(VENV)" PYTHON="$(CURDIR)/$(PYTHON)"
	@"$(PYTHON)" -m pre_commit install --allow-missing-config >/dev/null 2>&1 || true
	@echo "[OK] Setup complete.  Activate with:  source $(ACTIVATE_SCRIPT)"
endif

$(PYTHON):
	@echo "[INFO] Creating virtual environment at $(VENV)..."
	@"$(BOOTSTRAP_PYTHON)" -m venv "$(VENV)"
	@"$(PYTHON)" -m pip install --upgrade pip

$(ACTIVATE_SCRIPT): $(PYTHON)
	@$(MAKE) -C "$(ASSET_TOOLS)" setup VENV="$(CURDIR)/$(VENV)" PYTHON="$(CURDIR)/$(PYTHON)"
	@touch "$(ACTIVATE_SCRIPT)"

install:
	$(call check_dev_setup)
	@$(MAKE) -C "$(ASSET_TOOLS)" install VENV="$(CURDIR)/$(VENV)" PYTHON="$(CURDIR)/$(PYTHON)"
	@echo "[OK] Install complete"

# ── Lint & Format ────────────────────────────────────────────────────
# Root repo has no Python files — lint validates JSON-LD asset data.

lint: validate

format:
	$(call check_dev_setup)
	@echo "[INFO] Nothing to format (no Python files in root repo)"

# ── Validate ─────────────────────────────────────────────────────────

validate:
ifneq ($(firstword $(MAKECMDGOALS)),generate)
	$(call check_dev_setup)
	@"$(PYTHON)" -c "\
import pathlib, subprocess, sys; \
out = pathlib.Path('$(GEN_OUTPUT)'); \
dirs = [d for d in out.iterdir() if d.is_dir()] if out.exists() else []; \
sys.exit('[SKIP] No generated asset found (run: make generate)') if not dirs else None; \
asset = dirs[0]; \
manifest = asset / 'manifest.json'; \
metadata = asset / 'metadata' / 'hdmap.json'; \
paths = [str(p) for p in [manifest, metadata] if p.exists()]; \
sys.exit('[ERR] No manifest or metadata found in ' + str(asset)) if not paths else None; \
print('[INFO] Validating ' + str(asset.name) + ' against SHACL shapes...'); \
subprocess.check_call([ \
    '$(PYTHON)', '-m', 'src.tools.validators.validation_suite', \
    '--run', 'check-data-conformance', \
    '--data-paths'] + paths + [ \
    '--artifacts', '$(OMB)/artifacts'])"
	@echo "[OK] Validation complete"
endif

# ── Generate (full pipeline) ─────────────────────────────────────────

generate:
ifeq ($(SUBCMD),clean)
	@echo "[INFO] Removing generated/output/ directory..."
	@"$(PYTHON)" -c "import shutil; shutil.rmtree('$(GEN_OUTPUT)', ignore_errors=True)"
	@echo "[OK] Generated output removed (input/ blueprint preserved)"
else ifeq ($(SUBCMD),validate)
	$(call check_dev_setup)
	@"$(PYTHON)" -c "\
import pathlib, subprocess, sys; \
out = pathlib.Path('$(GEN_OUTPUT)'); \
dirs = [d for d in out.iterdir() if d.is_dir()] if out.exists() else []; \
sys.exit('[ERR] No generated asset found. Run: make generate') if not dirs else None; \
asset = dirs[0]; \
mf = asset / 'manifest.json'; \
md = asset / 'metadata' / 'hdmap.json'; \
missing = [f for f in [mf, md] if not f.exists()]; \
sys.exit('[ERR] Missing: ' + ', '.join(str(f) for f in missing)) if missing else print('[INFO] Validating ' + asset.name + '...'); \
rc = subprocess.call([sys.executable, '-m', 'src.tools.validators.validation_suite', '--run', 'check-data-conformance', '--data-paths', str(mf), str(md), '--artifacts', '$(OMB)/artifacts']); \
sys.exit(rc); \
"
	@echo "[OK] Generated asset validation complete"
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

# ── Asset packaging ──────────────────────────────────────────────────

asset:
ifeq ($(SUBCMD),zip)
	$(call check_dev_setup)
	@echo "[INFO] Creating asset zip..."
	@"$(PYTHON)" -c "\
import json, pathlib, zipfile; \
out = pathlib.Path('$(GEN_OUTPUT)'); \
dirs = [d for d in out.iterdir() if d.is_dir()] if out.exists() else []; \
assert dirs, '[ERR] No generated asset found. Run: make generate'; \
ad = dirs[0]; \
meta_path = ad / 'metadata' / 'hdmap.json'; \
meta = json.loads(meta_path.read_text(encoding='utf-8')); \
name = meta['hdmap:hasDataResource']['gx:name']['@value'].replace(' ', '_'); \
zf = zipfile.ZipFile(name + '.zip', 'w', zipfile.ZIP_DEFLATED); \
[zf.write(f, f.relative_to(ad)) for f in sorted(ad.rglob('*')) if f.is_file()]; \
zf.close(); \
print('[OK] Created ' + name + '.zip'); \
"
else
	@echo "[ERR] Unknown subcommand: $(SUBCMD)"
	@echo "Usage:  make asset zip"
	@exit 1
endif

# ── Clean ────────────────────────────────────────────────────────────

clean:
ifneq ($(firstword $(MAKECMDGOALS)),generate)
	@echo "[INFO] Cleaning..."
	@"$(PYTHON)" -c "\
import pathlib, shutil; \
[shutil.rmtree(str(d), ignore_errors=True) for d in ['build', 'dist', '.pytest_cache', '.mypy_cache', '$(GENERATED_DIR)']]; \
[shutil.rmtree(str(d), ignore_errors=True) for d in pathlib.Path('.').rglob('*.egg-info')]; \
[shutil.rmtree(str(d), ignore_errors=True) for d in pathlib.Path('.').rglob('__pycache__') if '$(ASSET_TOOLS)' not in str(d)]; \
[f.unlink() for f in pathlib.Path('.').glob('*.zip')]; \
"
	@echo "[OK] Cleaned"
endif

# ── Help ─────────────────────────────────────────────────────────────

help:
	@echo "hd-map-asset-example -- Available Commands"
	@echo ""
	@echo "  make setup              Create venv and install all dependencies"
	@echo "  make setup qc           Also install quality checker tools (optional, slow)"
	@echo "  make install            Install packages"
	@echo ""
	@echo "  make generate           Run full pipeline: .xodr -> generated/ asset"
	@echo "  make generate validate  Validate the generated asset"
	@echo "  make generate clean     Remove generated/ directory"
	@echo ""
	@echo "  make lint               Lint (validates asset JSON-LD)"
	@echo "  make validate           Validate generated/output/ asset against SHACL"
	@echo ""
	@echo "  make asset zip          Create asset zip for release"
	@echo ""
	@echo "  make clean              Remove all build artifacts, caches, and generated/"

# ── Catch-all for subcommand arguments ───────────────────────────────
ifneq ($(filter asset setup generate,$(firstword $(MAKECMDGOALS))),)
%:
	@:
endif
