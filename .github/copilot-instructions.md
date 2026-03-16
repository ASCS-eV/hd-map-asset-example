# HD-Map Asset Example — Copilot Instructions

## Project Overview

This is a **reference asset repository** for onboarding HD-Map simulation data into the ENVITED-X Dataspace. Users stage input files in `generated/input/`, then `make generate` runs the sl-5-8 pipeline to produce a complete, EVES-003-conformant asset in `generated/output/`.

Assets follow the [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html) specification.

## Asset Creation Flow

### Input → Output

Users provide an OpenDRIVE `.xodr` file and an `input_manifest.json` (plus optional images, docs, LICENSE) in `generated/input/`. The pipeline auto-extracts metadata, runs quality checks, generates GeoJSON previews, and packages everything into an EVES-003 asset in `generated/output/`.

### Two Paths

1. **Automated (default):** `make generate` — pipeline auto-extracts all metadata from the `.xodr` and input manifest. No user interaction needed.
2. **Wizard-assisted (optional):** `make wizard` starts a SHACL-driven web UI (Podman containers) at `http://localhost:4200` for interactively enriching metadata. Users can also edit `input_manifest.json` and `metadata/hdmap.json` by hand as an alternative to the wizard.

### Gaia-X Integration

The pipeline adds [Gaia-X Trust Framework](https://gaia-x.eu/) vocabulary to every asset (`gx:name`, `gx:license`, `gx:copyrightOwnedBy`, `gx:resourcePolicy`) inside `metadata/hdmap.json`. These properties live in closed GX-compliant nodes, while domain-specific properties (road types, lane counts, format version) go in open ENVITED-X wrapper shapes. The wizard's SHACL forms reflect both layers. Users don't need to understand Gaia-X — the pipeline handles compliance automatically.

### Pipeline Stages (18 total)

`meta_data_extractor` → `jsonLD_creator` → `shacl_combiner` → `wizard_caller` (disabled by default) → `jsonLD_validator` → `qualitychecker_caller` (ASAM + OpenMSL) → `xodr_routing_creator` → `xodr_to_geojson_caller` → `asset_reducer` → `structure_creator` → `manifest jsonLD_creator` → `jsonLD_validator`

Key config files are in `submodules/sl-5-8-asset-tools/configs/`. Each stage can be enabled/disabled via `process.json`.

## Repository Structure

- `generated/input/` — Staged pipeline inputs (manifest, `.xodr` files, media, docs)
- `generated/output/` — Pipeline output: complete EVES-003 asset ready for validation and release
- `submodules/sl-5-8-asset-tools/` — Asset creation and processing tools (git submodule from [openMSL/sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools))
  - `submodules/ontology-management-base/` — Nested submodule: SHACL shapes, OWL ontologies, JSON-LD contexts, and Python validation tools (from [ASCS-eV/ontology-management-base](https://github.com/ASCS-eV/ontology-management-base))

## Setup and Validation

```bash
make setup
make validate
```

All commands are exposed via `make` targets -- run `make help` for the full list.

## Linting (pre-commit hooks)

Configured in `.pre-commit-config.yaml` — all hooks delegate to `make` targets.

## Key Conventions

### Asset Structure (EVES-003)

Every asset must contain: `simulation-data/`, `metadata/`, `media/`, `documentation/`, and a `manifest.json` at the root. Optional: `validation-reports/`.

### JSON-LD Metadata

- `manifest.json` — Content registry linking all asset files with access roles (`isOwner`, `isRegistered`, `isPublic`) and categories (`isSimulationData`, `isMetadata`, `isMedia`, etc.)
- `metadata/hdmap.json` — Domain-specific metadata (format, content, quantity, quality, data source, georeference) conforming to the HD-Map SHACL shapes from ontology-management-base

Both files use typed `@value`/`@type` pairs for literals and reference ontologies via `@context` prefixes like `hdmap:`, `manifest:`, `envited-x:`, `georeference:`, `gx:`.

### Submodules

Two direct submodules:

- `submodules/sl-5-8-asset-tools` — Asset creation and processing tools (which contains `ontology-management-base` as a nested submodule)
- `submodules/EVES` — The [EVES specification](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html) that defines the structure and requirements for Simulation Assets in the ENVITED-X Dataspace

After cloning, initialize with:

```bash
make setup
```

### Commits

This project uses [DCO sign-off](CONTRIBUTING.md). All commits require `Signed-off-by` — use `git commit -s`. Do **not** add `Co-authored-by: Copilot` trailers.

## Release Workflow

The GitHub Actions workflow (`.github/workflows/release.yml`) triggers on version tags (`v*.*.*`), runs `make setup && make generate && make validate`, and uploads the pipeline-generated `asset.zip` as a GitHub release artifact.
