# HD-Map Asset Example

This repository serves as a reference for onboarding a HD-Map asset into the ENVITED-X Dataspace and can be used as a template for other dataspaces as well. It contains the full description as **`manifest.json`** in addition to a consistent example of an HD-Map asset data.

A complete **`asset`** in a specific domain includes the data itself and all necessary files for describing, evaluating, and visualizing the dataset.

The asset is generated from source files in `generated/input/` using the pipeline, and the release zip can be downloaded as an artifact from the latest release.

All ENVITED-X Dataspace assets are defined according to [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html).

## Prerequisites

| Tool | Why | Install |
|------|-----|---------|
| **Python 3.12+** | Pipeline runtime | [python.org](https://www.python.org/downloads/), Microsoft Store, or `winget install Python.Python.3.12` |
| **Git** | Submodule management | [git-scm.com](https://git-scm.com/downloads) (includes Git Bash on Windows) |
| **GNU Make** | Task runner | see below |

<details>
<summary><strong>Windows — installing Make</strong></summary>

**Git Bash / MSYS2** — Make is included if you selected the MSYS2 option during Git install, or install it with:

```bash
# Using Scoop (recommended)
scoop install make

# Using Chocolatey
choco install make
```

**PowerShell** — The same `scoop` or `choco` commands work. After installing, `make` uses Git's bundled `sh.exe` for recipe execution, so it works from PowerShell, Git Bash, and CMD alike.

**Without Make** — You can run the pipeline directly with Python (see [Option B](#option-b--run-the-pipeline-directly) below).

</details>

<details>
<summary><strong>macOS / Linux</strong></summary>

Make and Git are typically pre-installed. Install Python 3.12+ via your package manager:

```bash
# macOS
brew install python@3.12

# Ubuntu/Debian
sudo apt install python3.12 python3.12-venv
```

</details>

> **Podman** is only needed for `make wizard` (the SD Creation Wizard web UI). The pipeline itself does not require it. Podman is auto-installed by `make setup wizard` if missing.

## Quick Start

```bash
# 1. Clone with submodules
git clone --recurse-submodules <repo-url>
cd hd-map-asset-example

# 2. Install everything
make setup

# 3. Generate a complete asset from the example .xodr
make generate

# 4. Validate the generated asset
make generate validate
```

If already cloned without submodules:

```bash
git submodule update --init --recursive
make setup
```

## How It Works

The `generated/input/` folder contains the **pipeline inputs** — an OpenDRIVE `.xodr` file plus supplementary material (images, docs, license). `make generate` uses the [sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools) pipeline to produce a complete EVES-003 asset in `generated/output/`.

### What Gets Auto-Generated vs. Provided as Input

Everything begins with **one input file**: an OpenDRIVE (`.xodr`) HD-Map file. The pipeline auto-generates most of the asset — the rest is supplementary material you provide (screenshots, docs, license).

| File | Auto-Generated? | How |
|------|:---:|---|
| `simulation-data/*.xodr` | — | **Your input file** (the map itself) |
| `simulation-data/*.bjson` | ✅ | `asset_reducer` extracts a search-optimized binary JSON |
| `metadata/hdmap.json` | ✅ | `meta_data_extractor` → `jsonLD_creator` builds the JSON-LD |
| `manifest.json` | ✅ | `structure_creator` → `jsonLD_creator` builds the manifest |
| `media/roadNetwork.geojson` | ✅ | `xodr_routing_creator` converts road geometry to GeoJSON |
| `media/bbox.geojson` | ✅ | `xodr_routing_creator` computes the bounding box polygon |
| `media/3d_preview/*.json` | ✅ | `xodr_to_geojson_caller` converts road/lane/object geometry |
| `validation-reports/*_asam_*.xqar/.txt` | ✅ | `qualitychecker_caller` runs ASAM OpenDRIVE checks |
| `validation-reports/*_openmsl_*.xqar/.txt` | ✅ | `qualitychecker_caller` runs OpenMSL checks |
| `media/*.png` (screenshots) | ❌ | Manually captured in a map viewer |
| `documentation/*.pdf` | ❌ | Manually written documentation |
| `documentation/*_stats.txt` | ❌ | Manually created statistics |

### Pipeline Architecture

The asset creation pipeline runs as a sequence of modular steps, each building on the previous one's output:

```
  Your .xodr file  ──►  meta_data_extractor  ──►  jsonLD_creator (asset)
                         Parse .xodr XML            Build hdmap.json
                         🌐 geocoding

         │
         ├──►  shacl_combiner ──► jsonLD_validator
         │     Combine SHACL shapes    Validate metadata
         │
         ├──►  qualitychecker_caller   (optional: needs make setup qc)
         │     Run ASAM + OpenMSL checks → validation-reports/
         │
         ├──►  xodr_routing_creator
         │     .xodr → roadNetwork.geojson + bbox.geojson
         │
         ├──►  xodr_to_geojson_caller
         │     .xodr → 3d_preview/*.json (road/lane/object geometry)
         │
         ├──►  asset_reducer
         │     .xodr → .bjson (binary search index)
         │
         └──►  structure_creator ──► jsonLD_creator (manifest)
               Organize into EVES-003   Build manifest.json
               folder structure          ──► jsonLD_validator (manifest)

  🌐 = requires internet connection (reverse geocoding only)
```

## Generating an Asset (Step by Step)

### Step 1 — Set up the environment

```bash
make setup
```

Creates a Python virtual environment (`.venv/`) and installs the pipeline with all dependencies.

### Step 2 — (Optional) Install quality checkers

```bash
make setup qc
```

Installs the [ASAM](https://github.com/asam-ev/qc-opendrive) and [OpenMSL](https://github.com/openMSL/sl-5-9-openmsl-qc-opendrive) quality checkers from GitHub. Without these, the pipeline skips quality checking and produces no validation reports. The install takes a few minutes.

### Step 3 — Generate the asset

```bash
make generate
```

This single command:
1. **Reads** the `input_manifest.json` blueprint from `generated/input/`
2. **Runs** the full pipeline → outputs to `generated/output/<AssetName>/`
3. **Creates** a release-ready zip at `generated/output/<CID>.zip`

The generated asset contains the complete EVES-003 folder structure:

```
generated/output/<AssetName>/
├── simulation-data/    ← .xodr + .bjson search index
├── metadata/           ← hdmap.json (JSON-LD)
├── media/              ← GeoJSON maps + impression PNGs + 3D preview
├── documentation/      ← PDF + stats
├── validation-reports/ ← ASAM + OpenMSL QC reports
├── manifest.json
└── README.md
```

> 🌐 **Internet required for geocoding only** — reverse geocoding uses the Nominatim API. Ontology schemas and SHACL shapes are bundled via the `ontology-management-base` submodule.

### Step 4 — Validate the generated asset

```bash
make generate validate
```

Runs the SHACL validation suite against the generated `manifest.json` and `hdmap.json`.

### Step 5 — Clean up

```bash
make generate clean
```

Removes the `generated/output/` directory. Re-run `make generate` to regenerate.

## Creating Your Own Asset

To create a new HD-Map asset from **your own** `.xodr` file, you have two options:

### Option A — Use `make generate` (recommended)

1. Replace the `.xodr` in `generated/input/` with your own
2. Replace images and docs in `generated/input/` with yours
3. Update `generated/input/input_manifest.json` to list your files
4. Run `make generate clean && make generate`

The pipeline will run all steps and produce a fresh asset in `generated/output/`.

### Option B — Run the pipeline directly

You can invoke the pipeline from any directory without `make`. This works in **any shell** — Bash, PowerShell, CMD:

```bash
# Create a working directory with your input files
mkdir -p my_asset/input my_asset/output

# Copy your files into the input directory
cp path/to/your_map.xodr      my_asset/input/
cp path/to/screenshot.png      my_asset/input/
cp path/to/documentation.pdf   my_asset/input/
cp LICENSE                     my_asset/input/
```

Create `my_asset/input/input_manifest.json` (JSON-LD format — recommended):

> See `generated/input/input_manifest.json` in this repo for a complete example.

Or create `my_asset/input/uploadedFiles.json` (legacy array format):

```json
[
  {
    "filename": "your_map.xodr",
    "type": "Asset",
    "category": "isSimulationData",
    "did": "did:key:yourUniqueIdentifier"
  },
  {
    "filename": "documentation.pdf",
    "type": "Document",
    "category": "isDocumentation"
  },
  {
    "filename": "screenshot.png",
    "type": "Image",
    "category": "isMedia"
  },
  {
    "filename": "LICENSE",
    "type": "License",
    "category": "isLicense"
  }
]
```

Run the pipeline (paths can be relative or absolute — no need to `cd` into the input directory):

```bash
# Bash / Git Bash / macOS / Linux:
.venv/bin/python -m asset_extraction.main \
    my_asset/input/uploadedFiles.json \
    -config submodules/sl-5-8-asset-tools/configs \
    -out my_asset/output
```

```powershell
# PowerShell:
.\.venv\Scripts\python.exe -m asset_extraction.main `
    my_asset\input\uploadedFiles.json `
    -config submodules\sl-5-8-asset-tools\configs `
    -out my_asset\output
```

Supported file types and categories:

| Type | Category | Examples |
|------|----------|---------|
| `Asset` | `isSimulationData` | `.xodr`, `.xosc`, `.crg` |
| `Document` | `isDocumentation` | `.pdf`, `.txt`, `.md` |
| `Image` | `isMedia` | `.png`, `.jpg`, `.jpeg` |
| `Video` | `isMedia` | `.mp4` |
| `3DPreview` | `isMedia` | `.json` (3D visualization data) |
| `License` | `isLicense` | `LICENSE` |

## Repo Structure

📁 `.github` → GitHub Actions release workflow

📁 `generated/input` → Pipeline input files (`.xodr`, images, docs, license, `input_manifest.json`)

📁 `generated/output` → Pipeline output (auto-generated, not committed)

- 📁 `<AssetName>/simulation-data` → OpenDRIVE map file (`.xodr`) + search index (`.bjson`)
- 📁 `<AssetName>/metadata` → `hdmap.json` (domain-specific JSON-LD metadata)
- 📁 `<AssetName>/media` → Screenshots, GeoJSON maps, 3D preview data
- 📁 `<AssetName>/documentation` → PDF documentation and statistics
- 📁 `<AssetName>/validation-reports` → ASAM and OpenMSL quality check results
- 📄 `<AssetName>/manifest.json` → Content registry linking all files with access roles

📁 `submodules/sl-5-8-asset-tools`

- Asset creation and processing pipeline tools.
- Contains `ontology-management-base` as a nested submodule with all SHACLs and ontologies needed for validation.
- Versioned git submodule of [sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools).

📄 `CONTRIBUTING.md` → Contributing guidelines (DCO sign-off required)

📄 `Makefile` → Central command center for all operations

## Available Make Targets

```bash
make help               # Show all available commands

make setup              # Create venv and install all dependencies
make setup qc           # Also install quality checker tools (optional, slow)
make install            # Install packages

make generate           # Run full pipeline: .xodr → generated/ asset + zip
make generate validate  # Validate the generated asset
make generate clean     # Remove generated/output/ directory

make validate           # Validate the generated asset against SHACL
make lint               # Lint (same as validate)

make wizard             # Start SD Creation Wizard (Podman, auto-setup if needed)
make wizard stop        # Stop the wizard containers

make clean              # Remove all build artifacts, caches, and generated/
make clean all          # Clean + remove venv and submodules (full reset)
```

## FAQ

### How can I easily create a Simulation Asset?

- **One command:** Run `make generate` — it reads the input blueprint from `generated/input/`, runs the full pipeline, and outputs a complete EVES-003 asset to `generated/output/`.

- **Preparation:** Ensure you understood this repository and the necessary data to create a SimulationAsset for the ENVITED-X Data Space and familiarize yourself with the concept of an asset ([EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html)).

- **Guided Web UI:** You can use the [GaiaX 4 PLC-AAD Provider Tools](https://github.com/GAIA-X4PLC-AAD/provider-tools) to create your own asset in a guided way.

### Which roles can I define for access management?

- **isOwner**: The owner has full access to the asset and its associated files. This role includes permissions to download the asset.

- **isRegistered**: A registered user has access to certain files and data within the asset but can't download the asset.

- **isPublic**: A public user has only viewing rights to certain files or metadata.

### Which SHACL files are used to generate the domain metadata?

You need to use the following ontology from [Ontology Management Base Repository](https://github.com/ASCS-eV/ontology-management-base) — [HdMap Ontology](https://github.com/ASCS-eV/ontology-management-base/blob/main/artifacts/hdmap/hdmap.owl.ttl).

### What does the pipeline need to run?

- **Python 3.12+**, **Git**, and **GNU Make** (see [Prerequisites](#prerequisites))
- The `sl-5-8-asset-tools` submodule (initialized via `git submodule update --init --recursive` or `make setup`)
- **Internet connection** — required only for reverse geocoding (Nominatim API); ontology schemas and SHACL shapes are provided locally by the `ontology-management-base` submodule
- For quality checking (optional): run `make setup qc` to install the ASAM and OpenMSL checker tools from GitHub

### Debug logging

```bash
# Bash / Git Bash / macOS / Linux:
SL58_LOG_MODE=debug make generate

# PowerShell:
$env:SL58_LOG_MODE = "debug"; make generate

# Or with direct Python invocation:
$env:SL58_LOG_MODE = "debug"
.\.venv\Scripts\python.exe -m asset_extraction.main ...
```

Shows full subprocess command lines, stdout/stderr, and tracebacks.

### What is the `uploadedFiles.json`?

It's a simple JSON array that tells the pipeline which files to process and how to categorize them. Each entry has:
- `filename` — path or URL to the file
- `type` — what kind of file it is (`Asset`, `Document`, `Image`, `License`, etc.)
- `category` — the EVES-003 category (`isSimulationData`, `isDocumentation`, `isMedia`, etc.)
- `did` (optional) — a decentralized identifier for the asset

When using `make generate`, this file is created automatically.

### Known Limitations

- **Geocoding timeouts** — The `meta_data_extractor` uses the Nominatim API for reverse geocoding. If the API is slow or rate-limited, the pipeline may fail. Simply retry.
- **Quality checkers require extra install** — The `[qc]` optional dependencies install from Git branches and may take a while. Without them, quality checking is skipped (no validation reports generated). If you see stale checker errors after switching branches, run `make clean all && make setup` to get a fresh environment.
- **Ontology versions** — The pipeline generates metadata using the **latest** ontology versions. Both current and older versions are valid but produce different JSON-LD structures.

### Podman / Wizard Troubleshooting

The SD Creation Wizard (`make wizard`) uses Podman containers. Common issues on Windows:

| Error | Cause | Fix |
|-------|-------|-----|
| `CreateFile \\.\pipe\docker_engine: All pipe instances are busy` | Docker Desktop is running and holds the Docker API pipe | Quit Docker Desktop before starting Podman, or run `podman machine stop && podman machine start` |
| `machine not in running state` | Podman machine failed to start | Run `podman machine rm` then `podman machine init && podman machine start` |
| Port 4200 or 8080 already in use | Another process holds the port | `make wizard stop` first, or stop the other process |
