# HD-Map Asset Example

This repository serves as a reference for onboarding a HD-Map asset into the ENVITED-X Dataspace and can be used as a template for other dataspaces as well. It contains the full description as **`manifest_reference.json`** in addition to a consistent example of an HD-Map asset data.

A complete **`asset`** in a specific domain includes the data itself and all necessary files for describing, evaluating, and visualizing the dataset.

The repository has the following folder structure and the asset sample can be downloaded as artifact from the latest release (**`asset.zip`**).

All ENVITED-X Dataspace assets are defined according to [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html).

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

# 5. Package the hand-crafted example asset for release
make asset zip
```

If already cloned without submodules:

```bash
git submodule update --init --recursive
make setup
```

## How It Works

The `asset/` folder contains a **hand-crafted reference asset** — a complete, production-ready HD-Map for the ENVITED-X Dataspace. `make generate` uses the [sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools) pipeline to auto-generate a fresh asset from the same `.xodr` input into the `generated/` folder.

### What Gets Auto-Generated vs. Created Manually

Everything begins with **one input file**: an OpenDRIVE (`.xodr`) HD-Map file. The pipeline auto-generates roughly half of the asset — the rest is supplementary material you provide (screenshots, docs, license).

| File | Auto-Generated? | How |
|------|:---:|---|
| `simulation-data/*.xodr` | — | **Your input file** (the map itself) |
| `simulation-data/*.bjson` | ✅ | `asset_reducer` extracts a search-optimized binary JSON |
| `metadata/hdmap_instance.json` | ✅ | `meta_data_extractor` → `jsonLD_creator` builds the JSON-LD |
| `manifest_reference.json` | ✅ | `structure_creator` → `jsonLD_creator` builds the manifest |
| `media/roadNetwork.geojson` | ✅ | `xodr_routing_creator` converts road geometry to GeoJSON |
| `media/bbox.geojson` | ✅ | `xodr_routing_creator` computes the bounding box polygon |
| `validation-reports/*_asam_*.xqar/.txt` | ✅ | `qualitychecker_caller` runs ASAM OpenDRIVE checks |
| `validation-reports/*_openmsl_*.xqar/.txt` | ✅ | `qualitychecker_caller` runs OpenMSL checks |
| `media/*.png` (screenshots) | ❌ | Manually captured in a map viewer |
| `media/3d_preview/*.json` | ❌ | Manually exported from a 3D visualization tool |
| `documentation/*.pdf` | ❌ | Manually written documentation |
| `documentation/*_stats.txt` | ❌ | Manually created statistics |

### Pipeline Architecture

The asset creation pipeline runs as a sequence of modular steps, each building on the previous one's output:

```
  Your .xodr file  ──►  meta_data_extractor  ──►  jsonLD_creator (asset)
                         Parse .xodr XML            Build hdmap_instance.json
                         🌐 geocoding               🌐 fetch ontology

         │
         ├──►  shacl_combiner ──► jsonLD_validator
         │     🌐 download SHACL    Validate metadata
         │
         ├──►  qualitychecker_caller   (optional: needs make setup qc)
         │     Run ASAM + OpenMSL checks → validation-reports/
         │
         ├──►  xodr_routing_creator
         │     .xodr → roadNetwork.geojson + bbox.geojson
         │
         ├──►  asset_reducer
         │     .xodr → .bjson (binary search index)
         │
         └──►  structure_creator ──► jsonLD_creator (manifest)
               Organize into EVES-003   Build manifest_reference.json
               folder structure          ──► jsonLD_validator (manifest)

  🌐 = requires internet connection
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
1. **Stages** the `.xodr` from `asset/simulation-data/`, images from `asset/media/`, docs from `asset/documentation/`, and `LICENSE` into `generated/input/`
2. **Creates** `uploadedFiles.json` automatically from the staged files
3. **Runs** the full pipeline (14 steps) → outputs to `generated/output/<AssetName>/`

The generated asset contains the complete EVES-003 folder structure:

```
generated/output/<AssetName>/
├── simulation-data/    ← .xodr + .bjson search index
├── metadata/           ← hdmap_instance.json (JSON-LD)
├── media/              ← GeoJSON maps + impression PNGs
├── documentation/      ← PDF + stats
├── validation-reports/ ← ASAM + OpenMSL QC reports
├── manifest_reference.json
├── README.md
└── asset.zip
```

> 🌐 **Internet required** — the pipeline fetches ontology schemas, SHACL shapes, and geocoding data.

### Step 4 — Validate the generated asset

```bash
make generate validate
```

Runs the SHACL validation suite against the generated `manifest_reference.json` and `hdmap_instance.json`.

### Step 5 — Clean up

```bash
make generate clean
```

Removes the entire `generated/` directory. The `generated/` folder is in `.gitignore` and is never committed.

## Creating Your Own Asset

To create a new HD-Map asset from **your own** `.xodr` file, you have two options:

### Option A — Use `make generate` (recommended)

1. Replace the `.xodr` in `asset/simulation-data/` with your own
2. Replace images in `asset/media/` and docs in `asset/documentation/` with yours
3. Run `make generate`

The pipeline will auto-discover your input files, run all steps, and produce a fresh asset in `generated/output/`.

### Option B — Run the pipeline manually

Create a working directory with all your input files **and** an `uploadedFiles.json` manifest:

```bash
mkdir -p my_asset/input my_asset/output

# Copy your files into the input directory
cp path/to/your_map.xodr      my_asset/input/
cp path/to/screenshot.png      my_asset/input/
cp path/to/documentation.pdf   my_asset/input/
cp LICENSE                     my_asset/input/
```

Create `my_asset/input/uploadedFiles.json`:

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

Run the pipeline:

```bash
cd my_asset/input

# Windows:
../../.venv/Scripts/python -m asset_extraction.main \
    uploadedFiles.json \
    -config ../../submodules/sl-5-8-asset-tools/configs \
    -out ../output

# macOS/Linux:
../../.venv/bin/python -m asset_extraction.main \
    uploadedFiles.json \
    -config ../../submodules/sl-5-8-asset-tools/configs \
    -out ../output
```

> ⚠️ **Important path rules:**
> - All input files **must be in the same directory** as `uploadedFiles.json`
> - Use **bare filenames** (no subdirectories) in `uploadedFiles.json`
> - The **output directory must be separate** from the input directory

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

📁 `asset` → The complete hand-crafted example asset ([details](asset/README.md))

- 📁 `simulation-data` → OpenDRIVE map file (`.xodr`) + search index (`.bjson`)
- 📁 `metadata` → `hdmap_instance.json` (domain-specific JSON-LD metadata)
- 📁 `media` → Screenshots, GeoJSON maps, 3D preview data
- 📁 `documentation` → PDF documentation and statistics
- 📁 `validation-reports` → ASAM and OpenMSL quality check results
- 📄 `manifest_reference.json` → Content registry linking all files with access roles

📁 `generated` → Pipeline output (auto-generated, git-ignored)

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

make generate           # Run full pipeline: .xodr → generated/ asset
make generate validate  # Validate the generated asset
make generate clean     # Remove generated/ directory

make validate           # Validate the hand-crafted asset/ against SHACL
make lint               # Lint (validates asset JSON-LD)

make asset zip          # Create asset zip for release
make clean              # Remove all build artifacts, caches, and generated/
```

## FAQ

### How can I easily create a Simulation Asset?

- **One command:** Run `make generate` — it stages files from `asset/`, runs the full pipeline, and outputs a complete EVES-003 asset to `generated/`.

- **Preparation:** Ensure you understood this repository and the necessary data to create a SimulationAsset for the ENVITED-X Data Space and familiarize yourself with the concept of an asset ([EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html)).

- **Guided Web UI:** You can use the [GaiaX 4 PLC-AAD Provider Tools](https://github.com/GAIA-X4PLC-AAD/provider-tools) to create your own asset in a guided way.

### Which roles can I define for access management?

- **isOwner**: The owner has full access to the asset and its associated files. This role includes permissions to download the asset.

- **isRegistered**: A registered user has access to certain files and data within the asset but can't download the asset.

- **isPublic**: A public user has only viewing rights to certain files or metadata.

### Which SHACL files are used to generate the domain metadata?

You need to use the following ontology from [Ontology Management Base Repository](https://github.com/ASCS-eV/ontology-management-base) — [HdMap Ontology](https://github.com/ASCS-eV/ontology-management-base/blob/main/artifacts/hdmap/hdmap.owl.ttl).

### What does the pipeline need to run?

- **Python 3.12+** and `make`
- The `sl-5-8-asset-tools` submodule (initialized via `git submodule update --init --recursive`)
- **Internet connection** — required for geocoding (Nominatim API), fetching ontology schemas (w3id.org), and downloading SHACL shapes
- For quality checking (optional): run `make setup qc` to install the ASAM and OpenMSL checker tools from GitHub

### What is the `uploadedFiles.json`?

It's a simple JSON array that tells the pipeline which files to process and how to categorize them. Each entry has:
- `filename` — path or URL to the file
- `type` — what kind of file it is (`Asset`, `Document`, `Image`, `License`, etc.)
- `category` — the EVES-003 category (`isSimulationData`, `isDocumentation`, `isMedia`, etc.)
- `did` (optional) — a decentralized identifier for the asset

When using `make generate`, this file is created automatically.

### Known Limitations

- **Geocoding timeouts** — The `meta_data_extractor` uses the Nominatim API for reverse geocoding. If the API is slow or rate-limited, the pipeline may fail. Simply retry.
- **Quality checkers require extra install** — The `[qc]` optional dependencies install from Git branches and may take a while. Without them, quality checking is skipped (no validation reports generated).
- **Ontology versions** — The pipeline generates metadata using the **latest** ontology versions (currently v6 for HD-Map). The existing hand-crafted example in `asset/` uses v4. Both are valid but produce different JSON-LD structures.
- **GeoJSON converter disabled** — The `xodr_to_geojson_caller` step requires a Java runtime and the VCS converter JAR, which is not bundled. It is disabled by default in `configs/process.json`.
