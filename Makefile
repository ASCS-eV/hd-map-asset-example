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
	@if ! "$(PYTHON)" -c "import rdflib, pyshacl" >/dev/null 2>&1; then \
		echo "[INFO] Dependencies missing — reinstalling..."; \
		"$(PYTHON)" -m pip install -e "$(ASSET_TOOLS)[dev]"; \
		"$(PYTHON)" -m pip install -e "$(OMB)"; \
	fi
	@echo "[OK] Setup complete.  Activate with:  source $(ACTIVATE_SCRIPT)"
endif

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
ifneq ($(firstword $(MAKECMDGOALS)),generate)
	$(call check_dev_setup)
	@echo "[INFO] Validating asset JSON-LD against SHACL shapes..."
	@"$(PYTHON)" -m src.tools.validators.validation_suite \
		--run check-data-conformance \
		--data-paths $(ASSET_DIR)/manifest_reference.json $(METADATA) \
		--artifacts "$(OMB)/artifacts"
	@echo "[OK] Validation complete"
endif

# ── Generate (full pipeline) ─────────────────────────────────────────

generate:
ifeq ($(SUBCMD),clean)
	@echo "[INFO] Removing generated/ directory..."
	@"$(PYTHON)" -c "import shutil; shutil.rmtree('$(GENERATED_DIR)', ignore_errors=True)"
	@echo "[OK] Generated directory removed"
else ifeq ($(SUBCMD),validate)
	$(call check_dev_setup)
	@"$(PYTHON)" -c "\
import pathlib, subprocess, sys; \
out = pathlib.Path('$(GEN_OUTPUT)'); \
dirs = [d for d in out.iterdir() if d.is_dir()] if out.exists() else []; \
sys.exit('[ERR] No generated asset found. Run: make generate') if not dirs else None; \
asset = dirs[0]; \
mf = asset / 'manifest_reference.json'; \
md = asset / 'metadata' / 'hdmap_instance.json'; \
missing = [f for f in [mf, md] if not f.exists()]; \
sys.exit('[ERR] Missing: ' + ', '.join(str(f) for f in missing)) if missing else print('[INFO] Validating ' + asset.name + '...'); \
rc = subprocess.call([sys.executable, '-m', 'src.tools.validators.validation_suite', '--run', 'check-data-conformance', '--data-paths', str(mf), str(md), '--artifacts', '$(OMB)/artifacts']); \
sys.exit(rc); \
"
	@echo "[OK] Generated asset validation complete"
else
	$(call check_dev_setup)
	@echo "[INFO] Staging input files..."
	@"$(PYTHON)" -c "\
import json, pathlib, shutil; \
inp = pathlib.Path('$(GEN_INPUT)'); \
inp.mkdir(parents=True, exist_ok=True); \
pathlib.Path('$(GEN_OUTPUT)').mkdir(parents=True, exist_ok=True); \
sd = pathlib.Path('$(ASSET_DIR)/simulation-data'); \
xodrs = list(sd.glob('*.xodr')); \
assert xodrs, 'No .xodr file found in $(ASSET_DIR)/simulation-data/'; \
xodr = xodrs[0]; \
shutil.copy(str(xodr), str(inp / xodr.name)); \
artifacts = []; \
artifacts.append({'@type': 'Link', 'hasCategory': {'@id': 'envited-x:isSimulationData'}, 'hasAccessRole': {'@id': 'envited-x:isOwner'}, 'hasFileMetadata': {'@type': 'FileMetadata', 'filePath': xodr.name, 'mimeType': 'application/xml'}}); \
imgs = sorted(list(pathlib.Path('$(ASSET_DIR)/media').glob('*.png')) + list(pathlib.Path('$(ASSET_DIR)/media').glob('*.jpg'))); \
mime_map = {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg'}; \
[((dst_name := 'impression-' + str(i).zfill(2) + img.suffix), shutil.copy(str(img), str(inp / dst_name)), artifacts.append({'@type': 'Link', 'hasCategory': {'@id': 'envited-x:isMedia'}, 'hasAccessRole': {'@id': 'envited-x:isPublic'}, 'hasFileMetadata': {'@type': 'FileMetadata', 'filePath': dst_name, 'mimeType': mime_map.get(img.suffix, 'application/octet-stream')}})) for i, img in enumerate(imgs, 1)]; \
docs = sorted(list(pathlib.Path('$(ASSET_DIR)/documentation').glob('*.pdf')) + list(pathlib.Path('$(ASSET_DIR)/documentation').glob('*.txt'))); \
doc_mime = {'.pdf': 'application/pdf', '.txt': 'text/plain', '.md': 'text/markdown'}; \
[(shutil.copy(str(doc), str(inp / doc.name)), artifacts.append({'@type': 'Link', 'hasCategory': {'@id': 'envited-x:isDocumentation'}, 'hasAccessRole': {'@id': 'envited-x:isPublic'}, 'hasFileMetadata': {'@type': 'FileMetadata', 'filePath': doc.name, 'mimeType': doc_mime.get(doc.suffix, 'text/plain')}})) for doc in docs]; \
lic = pathlib.Path('LICENSE'); \
license_link = None; \
(shutil.copy(str(lic), str(inp / 'LICENSE')), license_link := {'@type': 'Link', 'hasCategory': {'@id': 'envited-x:isLicense'}, 'hasAccessRole': {'@id': 'envited-x:isPublic'}, 'hasFileMetadata': {'@type': 'FileMetadata', 'filePath': 'LICENSE', 'mimeType': 'text/plain'}}) if lic.exists() else None; \
manifest = {'@context': ['https://w3id.org/ascs-ev/envited-x/manifest/v5/', {'envited-x': 'https://w3id.org/ascs-ev/envited-x/envited-x/v3/'}], '@id': 'did:web:registry.gaia-x.eu:HdMap:generated', '@type': 'envited-x:Manifest', 'hasArtifacts': artifacts}; \
manifest['hasLicense'] = license_link if license_link else {'@type': 'Link', 'hasCategory': {'@id': 'envited-x:isLicense'}, 'hasAccessRole': {'@id': 'envited-x:isPublic'}, 'hasFileMetadata': {'@type': 'FileMetadata', 'filePath': 'https://www.mozilla.org/en-US/MPL/2.0/', 'mimeType': 'text/html'}}; \
(inp / 'input_manifest.json').write_text(json.dumps(manifest, indent=2)); \
print('[OK] Staged ' + str(len(artifacts) + 1) + ' files in $(GEN_INPUT)/'); \
"
	@echo "[INFO] Running asset creation pipeline..."
	@cd "$(GEN_INPUT)" && "$(CURDIR)/$(PYTHON)" -m asset_extraction.main \
		input_manifest.json \
		-config "$(CURDIR)/$(GEN_CONFIGS)" \
		-out "$(CURDIR)/$(GEN_OUTPUT)"
	@echo ""
	@echo "[OK] Asset generated in $(GEN_OUTPUT)/"
	@"$(PYTHON)" -c "\
import pathlib, zipfile; \
out = pathlib.Path('$(GEN_OUTPUT)'); \
dirs = [d for d in out.iterdir() if d.is_dir()]; \
asset = dirs[0] if dirs else None; \
files = list(asset.rglob('*')) if asset else []; \
real = [f for f in files if f.is_file() and 'temp' not in f.parts]; \
zf_path = out / (asset.name + '.zip'); \
zf = zipfile.ZipFile(str(zf_path), 'w', zipfile.ZIP_DEFLATED); \
[zf.write(str(f), str(f.relative_to(asset))) for f in sorted(real)]; \
zf.close(); \
print('     Asset:  ' + asset.name + '/'); \
print('     Files:  ' + str(len(real))); \
print('     Zip:    ' + zf_path.name + ' (' + str(round(zf_path.stat().st_size / 1024)) + ' KB)'); \
" 2>/dev/null || true
endif

# ── Asset packaging ──────────────────────────────────────────────────

asset:
ifeq ($(SUBCMD),zip)
	$(call check_dev_setup)
	@echo "[INFO] Creating asset zip..."
	@"$(PYTHON)" -c "\
import json, pathlib, zipfile; \
meta = json.loads(pathlib.Path('$(METADATA)').read_text(encoding='utf-8')); \
name = meta['hdmap:hasDataResource']['gx:name']['@value'].replace(' ', '_'); \
ad = pathlib.Path('$(ASSET_DIR)'); \
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
	@echo "  make validate           Validate the hand-crafted asset/ against SHACL"
	@echo ""
	@echo "  make asset zip          Create asset zip for release"
	@echo ""
	@echo "  make clean              Remove all build artifacts, caches, and generated/"

# ── Catch-all for subcommand arguments ───────────────────────────────
ifneq ($(filter asset setup generate,$(firstword $(MAKECMDGOALS))),)
%:
	@:
endif
