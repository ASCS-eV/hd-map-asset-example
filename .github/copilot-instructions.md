# HD-Map Asset Example — Copilot Instructions

## Project Overview

This is a **reference asset repository** for onboarding HD-Map simulation data into the ENVITED-X Dataspace. Users stage input files in `generated/input/`, then `make generate` runs the sl-5-8 pipeline to produce a complete, EVES-003-conformant asset in `generated/output/`.

Assets follow the [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html) specification.

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

Every asset must contain: `simulation-data/`, `metadata/`, `media/`, `documentation/`, and a `manifest_reference.json` at the root. Optional: `validation-reports/`.

### JSON-LD Metadata

- `manifest_reference.json` — Content registry linking all asset files with access roles (`isOwner`, `isRegistered`, `isPublic`) and categories (`isSimulationData`, `isMetadata`, `isMedia`, etc.)
- `metadata/hdmap_instance.json` — Domain-specific metadata (format, content, quantity, quality, data source, georeference) conforming to the HD-Map SHACL shapes from ontology-management-base

Both files use typed `@value`/`@type` pairs for literals and reference ontologies via `@context` prefixes like `hdmap:`, `manifest:`, `envited-x:`, `georeference:`, `gx:`.

### Submodules

Only one direct submodule: `submodules/sl-5-8-asset-tools` (which contains `ontology-management-base` as a nested submodule). After cloning, initialize with:

```bash
make setup
```

### Commits

This project uses [DCO sign-off](CONTRIBUTING.md). All commits require `Signed-off-by` — use `git commit -s`. Do **not** add `Co-authored-by: Copilot` trailers.

## Release Workflow

The GitHub Actions workflow (`.github/workflows/release.yml`) triggers on version tags (`v*.*.*`), runs `make setup && make validate`, zips the generated asset via `make asset zip`, and uploads it as a GitHub release artifact.
