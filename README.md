# HD-Map Asset Example

This repository demonstrates how to transform an [ASAM OpenDRIVE](https://www.asam.net/standards/detail/opendrive/) map (`.xodr`) into a **Simulation Asset** — a standardized, quality-checked, machine-readable package that can be shared with partners and integrated into simulation workflows.

A Simulation Asset enriches raw map data with:

- **Structured metadata** — road types, lane counts, geolocation, format version (JSON-LD)
- **Quality reports** — automated ASAM and OpenMSL compliance checks
- **Visual previews** — GeoJSON maps, bounding box, 3D road/lane geometry
- **Access control** — per-file visibility roles (owner, registered, public) for data marketplace use
- **Content-addressed packaging** — deterministic CID-named archive for integrity verification

The asset structure follows [EVES-003][eves-003], the specification that defines folder
layout and metadata schemas for Simulation Assets in the
[ENVITED-X Dataspace](https://2025.2.envited-x.net).
This repository serves as both a working reference and a template for creating new assets.

[eves-003]: https://ascs-ev.github.io/EVES/EVES-003/eves-003.html

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

> **Podman** is only needed for `make wizard` (the SD Creation Wizard web UI). The pipeline itself does not require it. Podman is auto-installed when you first run `make wizard` if missing.

## Quick Start

```bash
# 1. Clone with submodules
git clone --recurse-submodules https://github.com/ASCS-eV/hd-map-asset-example.git
cd hd-map-asset-example

# 2. Install everything
make setup

# 3. Generate a complete asset from the example .xodr
make generate

# 4. Validate the generated asset
make validate
```

If already cloned without submodules:

```bash
git submodule update --init --recursive
make setup
```

## How It Works

The `generated/input/` folder contains the **pipeline inputs** — an OpenDRIVE `.xodr` file plus supplementary material (images, docs, license). `make generate` uses the [sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools) pipeline to produce a complete EVES-003 asset in `generated/output/`.

### Input → Output at a Glance

```text
  generated/input/                              generated/output/<AssetName>/
  ├── input_manifest.json  ─── make generate ──►  ├── simulation-data/   (.xodr + .bjson)
  ├── YourMap.xodr                                ├── metadata/          (hdmap.json)
  ├── impression-01.png                           ├── media/             (GeoJSON, PNGs, 3D)
  ├── documentation.pdf                           ├── documentation/     (PDF, stats)
  ├── LICENSE                                     ├── validation-reports/(QC results)
  └── (optional extras)                           ├── manifest.json
                                                  └── LICENSE
                                                ──► <CID>.zip  (release archive)
```

**You provide:** a `.xodr` map file, an `input_manifest.json` describing your files, and optional supplementary material (screenshots, docs, license).

**The pipeline generates:** domain metadata (`hdmap.json`), GeoJSON maps, 3D preview data, quality check reports, a search index, and the `manifest.json` content registry — all packaged as an EVES-003 asset.

### Two Workflows for Creating Assets

| | **Automated (default)** | **Wizard-assisted (optional)** |
|---|---|---|
| **How** | `make generate` | `make wizard` → edit in browser → `make generate` |
| **Metadata source** | Auto-extracted from `.xodr` + `input_manifest.json` | Auto-extracted + manually enriched via SHACL-driven web form |
| **When to use** | CI/CD, standard assets, bulk processing | First-time asset creation, when you need to add domain-specific details the extractor can't infer |
| **Requires** | Python, Make | Python, Make, Podman |

**Automated path:** Place your files in `generated/input/`, create an `input_manifest.json`, run `make generate`. The pipeline auto-extracts all metadata from your `.xodr` file — road types, lane counts, georeferencing, format version, etc.

**Wizard path:** Start the SD Creation Wizard with `make wizard`, open `http://localhost:4200`, load the SHACL shapes for your domain, and fill in any metadata the extractor cannot infer. Export the enriched JSON-LD, place it in your input folder, then run `make generate`.

### Metadata and Gaia-X

The generated metadata uses the [Gaia-X Trust Framework](https://gaia-x.eu/) vocabulary alongside ENVITED-X domain ontologies. This enables Simulation Assets to participate in Gaia-X-compliant data ecosystems.

**What Gaia-X adds to your asset:**

| Property | Source | Example |
|----------|--------|---------|
| `gx:name` | Auto-extracted from `.xodr` filename | `"Testfeld_Niedersachsen_..."` |
| `gx:description` | Auto-extracted from `.xodr` content | `"road network"` |
| `gx:license` | Auto-detected from `LICENSE` file | `"MPL-2.0"` |
| `gx:copyrightOwnedBy` | Parsed from license text | `"see contributors"` |
| `gx:resourcePolicy` | Default | `"allow"` |

These properties live inside `metadata/hdmap.json` as part of an `envited-x:ResourceDescription` node. The asset is identified by a DID (`did:web:registry.gaia-x.eu:HdMap:{UUID}`).

**Design pattern:** ENVITED-X uses a wrapper architecture — Gaia-X properties go in closed GX-compliant nodes, while domain-specific properties (road types, lane geometry, format version) go in open ENVITED-X shapes. This keeps domain extensions from violating Gaia-X's strict SHACL constraints.

> **You don't need to know Gaia-X to use this repo.** The pipeline handles all GX compliance automatically. The wizard provides a form UI if you want to inspect or edit the GX metadata.

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

```text
  Your .xodr file  ──►  meta_data_extractor  ──►  jsonLD_creator (asset)
                         Parse .xodr XML            Build hdmap.json
                         🌐 geocoding

         │
         ├──►  shacl_combiner ──► jsonLD_validator
         │     Combine SHACL shapes    Validate metadata
         │
         ├──►  qualitychecker_caller
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

### Step 2 — Generate the asset

```bash
make generate
```

This single command:

1. **Reads** the `input_manifest.json` blueprint from `generated/input/`
2. **Runs** the full pipeline → outputs to `generated/output/<AssetName>/`
3. **Creates** a release-ready zip at `generated/output/<CID>.zip`

The generated asset contains the complete EVES-003 folder structure:

```text
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

### Step 3 — Validate the generated asset

```bash
make validate
```

Runs the SHACL validation suite against the generated `manifest.json` and `hdmap.json`.

### Step 4 — Clean up

```bash
make generate clean
```

Removes the `generated/output/` directory. Re-run `make generate` to regenerate.

## Creating Your Own Asset

To create a new HD-Map asset from **your own** `.xodr` file, you have two options:

### Option A — Use `make generate` (recommended)

1. Replace the `.xodr` in `generated/input/` with your own
2. Replace images and docs in `generated/input/` with yours
3. Update `generated/input/input_manifest.json` to list your files (see below)
4. Run `make generate clean && make generate`

The pipeline will run all steps and produce a fresh asset in `generated/output/`.

#### Writing your `input_manifest.json`

The `input_manifest.json` tells the pipeline which files to process, how to categorize them, and who can access them. Here's a minimal example:

```json
{
  "@context": [
    "https://w3id.org/ascs-ev/envited-x/manifest/v5/",
    { "envited-x": "https://w3id.org/ascs-ev/envited-x/envited-x/v3/" }
  ],
  "@id": "did:web:registry.gaia-x.eu:HdMap:generated",
  "@type": "envited-x:Manifest",
  "hasArtifacts": [
    {
      "@type": "Link",
      "hasCategory": { "@id": "envited-x:isSimulationData" },
      "hasAccessRole": { "@id": "envited-x:isOwner" },
      "hasFileMetadata": {
        "@type": "FileMetadata",
        "filePath": "your_map.xodr",
        "mimeType": "application/xml"
      }
    },
    {
      "@type": "Link",
      "hasCategory": { "@id": "envited-x:isMedia" },
      "hasAccessRole": { "@id": "envited-x:isPublic" },
      "hasFileMetadata": {
        "@type": "FileMetadata",
        "filePath": "screenshot.png",
        "mimeType": "image/png"
      }
    }
  ],
  "hasLicense": {
    "@type": "Link",
    "hasCategory": { "@id": "envited-x:isLicense" },
    "hasAccessRole": { "@id": "envited-x:isPublic" },
    "hasFileMetadata": {
      "@type": "FileMetadata",
      "filePath": "LICENSE",
      "mimeType": "text/plain"
    }
  }
}
```

**Field reference:**

| Field | Purpose | Values |
|-------|---------|--------|
| `filePath` | Filename relative to the input directory | Any filename present in the folder |
| `mimeType` | MIME type of the file | `application/xml`, `image/png`, `application/pdf`, `text/plain`, etc. |
| `hasCategory` | EVES-003 category | `envited-x:isSimulationData`, `envited-x:isMedia`, `envited-x:isDocumentation`, `envited-x:isLicense` |
| `hasAccessRole` | Who can access this file | `envited-x:isOwner` (download), `envited-x:isRegistered` (view), `envited-x:isPublic` (browse) |

> **LICENSE is required.** Every asset must declare a license via the `hasLicense` field. See `generated/input/input_manifest.json` for a complete working example.

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

Create `my_asset/input/input_manifest.json` using the template above, then run:

```bash
# Bash / Git Bash / macOS / Linux:
.venv/bin/python -m asset_extraction.main \
    my_asset/input/input_manifest.json \
    -config submodules/sl-5-8-asset-tools/configs \
    -out my_asset/output
```

```powershell
# PowerShell:
.\.venv\Scripts\python.exe -m asset_extraction.main `
    my_asset\input\input_manifest.json `
    -config submodules\sl-5-8-asset-tools\configs `
    -out my_asset\output
```

## What Partners Get

When you share the generated asset (the `<CID>.zip`), recipients get a self-contained package they can evaluate without asking you anything:

| What | How it helps partners |
|------|----------------------|
| **`manifest.json`** | Machine-readable content registry — partners' tools can automatically index, search, and verify every file in the asset |
| **`metadata/hdmap.json`** | Structured domain metadata — road types, lane counts, coordinate system, geographic bounds — queryable without opening the map |
| **`validation-reports/`** | Transparent quality — ASAM and OpenMSL compliance reports show exactly which checks passed or failed |
| **`media/roadNetwork.geojson`** | Visual preview — partners can render the road network on a map without a specialized viewer |
| **`media/3d_preview/`** | 3D geometry — roads, lanes, junctions, signals as lightweight JSON for web-based visualization |
| **Access roles** | Per-file access control — you decide what's public (previews), registered-only (docs), or owner-only (raw data) |
| **CID naming** | Content-addressed zip — the filename IS the hash, so partners can verify integrity without trusting the transport |

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

📁 `submodules/EVES`

- The [EVES specification](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html) — defines the structure and requirements for Simulation Assets in the ENVITED-X Dataspace.
- Versioned git submodule of [EVES](https://github.com/ASCS-eV/EVES).

📄 `CONTRIBUTING.md` → Contributing guidelines (DCO sign-off required)

📄 `Makefile` → Central command center for all operations

## Available Make Targets

```bash
make help               # Show all available commands

make setup              # Create venv and install all dependencies (incl. QC tools)
make install            # Install packages

make generate           # Run full pipeline: .xodr → generated/ asset + zip
make generate clean     # Remove generated/output/ directory

make validate           # Validate the generated asset against SHACL
make lint               # Lint (validate + markdown lint)
make lint-md            # Lint Markdown files only
make format             # Auto-fix Markdown lint issues

make wizard             # Start SD Creation Wizard (Podman, auto-setup if needed)
make wizard stop        # Stop the wizard containers

make clean              # Remove all build artifacts, caches, and generated/
make clean all          # Clean + remove venv and submodules (full reset)
```

## FAQ

### How can I easily create a Simulation Asset?

- **One command:** Run `make generate` — it reads the input blueprint from `generated/input/`, runs the full pipeline, and outputs a complete EVES-003 asset to `generated/output/`.

- **Preparation:** Ensure you understood this repository and the necessary data to create a SimulationAsset for the ENVITED-X Data Space and familiarize yourself with the concept of an asset ([EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html)).

- **Guided Web UI:** Run `make wizard` to start the SD Creation Wizard — a SHACL-driven web form for inspecting and enriching asset metadata. See [Two Workflows for Creating Assets](#two-workflows-for-creating-assets) above.

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
- Quality checkers (ASAM + OpenMSL) are installed automatically by `make setup`

### How do I enable debug logging?

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

### How do I get reproducible output?

```bash
# Bash / Git Bash / macOS / Linux:
SL58_DETERMINISTIC=1 make generate

# PowerShell:
$env:SL58_DETERMINISTIC = "1"; make generate
```

Same input files produce identical UUIDs, timestamps, and CID — useful for CI and diffing.

### Known Limitations

- **Geocoding timeouts** — The `meta_data_extractor` uses the Nominatim API for reverse geocoding. If the API is slow or rate-limited, the pipeline may fail. Simply retry.
- **Quality checkers install from Git branches** — The `[qc]` optional dependencies (installed automatically by `make setup`) pull from Git branches and may take a while on first install. If you see stale checker errors after switching branches, run `make clean all && make setup` to get a fresh environment.
- **Ontology versions** — The pipeline generates metadata using the **latest** ontology versions. Both current and older versions are valid but produce different JSON-LD structures.

### Podman / Wizard Troubleshooting

The SD Creation Wizard (`make wizard`) uses Podman containers. Common issues on Windows:

| Error | Cause | Fix |
|-------|-------|-----|
| `CreateFile \\.\pipe\docker_engine: All pipe instances are busy` | Docker Desktop is running and holds the Docker API pipe | Quit Docker Desktop before starting Podman, or run `podman machine stop && podman machine start` |
| `machine not in running state` | Podman machine failed to start | Run `podman machine rm` then `podman machine init && podman machine start` |
| Port 4200 or 8080 already in use | Another process holds the port | `make wizard stop` first, or stop the other process |
