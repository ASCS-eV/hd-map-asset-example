# HD-Map Asset Example

This repository serves as a reference for onboarding a HD-Map asset into the ENVITED X Dataspace and can be used as a template for other dataspaces as well. It contains the full description as **`manifest_reference.json` - file** in addition to a consistent example of an HD-Map asset data.

A complete **`asset`** in a specific domain includes the data itself and all necessary files for describing, evaluating, and visualizing the dataset.

The repository has the following folder structure and the asset sample can be downloaded as artifact from the lastest release (**`asset.zip`**).

All ENVITED X Dataspace assets are defined according to [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html).

## Installation

```bash
git clone --recurse-submodules <repo-url>
cd hd-map-asset-example
make setup
```

Or if already cloned:

```bash
make setup
```

## Validation

```bash
make validate
```

## Repo Structure

The Repo has the following structure:

📁 `.github` *-> github workflows*

📁 `asset` *-> contains the asset*

- 📄 *`README.md`* <i style="color:gray;">(defines asset folder structure)</i>
- 📄 *`..more..`* <i style="color:gray;">(see folder)</i>

📁 `submodules/sl-5-8-asset-tools`

- Asset creation and processing pipeline tools.
- Contains `ontology-management-base` as a nested submodule with all SHACLs and ontologies needed for validation.
- Versioned git submodule of [sl-5-8-asset-tools](https://github.com/openMSL/sl-5-8-asset-tools).

📄 `CONTRIBUTING.md` *-> contributing guidelines*

📄 `README.md` *-> documentation of the Repo and the asset*

### Legend

- 📁 `folder-name`: A folder in the repo.
- 📄 `assetName`: A file in the repo.
- <i style="color:gray;">(optional)</i> : This file or folder is optional and can be added or omitted as needed.

## Available Make Targets

```bash
make help       # Show all available commands
make setup      # Create venv and install dependencies
make validate   # Validate asset JSON-LD against SHACL shapes
make lint       # Lint (validates asset JSON-LD)
make asset zip  # Create asset zip for release
make clean      # Remove build artifacts
```

## FAQ

### How can I easily create a Simulation Asset?

- **Preparation :** *Ensure you understood this repository and the necessary data to create a SimulationAsset for the ENVITED-X Data Space and familiarize yourself with the concept of an asset [EVES-003](https://ascs-ev.github.io/EVES/EVES-003/eves-003.html).*

- **Provider Tools :** *You can use the [GaiaX 4 PLC-AAD Provider Tools](https://github.com/GAIA-X4PLC-AAD/provider-tools) to create your own asset in a guided way.*

### Which roles can I define for access management?

- **isOwner** *: The owner has full access to the asset and its associated files. This role includes permissions to download the asset.*

- **isRegistered** *: A registered user has access to certain files and data within the asset but can't download the asset.*

- **isPublic** *: A public user has only viewing rights to certain files or metadata.*

### Which SHACL - Files are used to generate the domainMetadata.json ?

-You need to use the following Ontology from [Ontology Management Base Repository](https://github.com/ASCS-eV/ontology-management-base) - [HdMap_Ontology](https://github.com/ASCS-eV/ontology-management-base/blob/main/artifacts/hdmap/hdmap.owl.ttl).

## Usage

  1. Read the `README.md` - file.
  2. Download the lastest `asset.zip` - file release.
  3. Explore the provided data files and documentation.
  4. Create the same folder and file structure for your asset, along with an appropriate `hdmap_instance.json` - file and `manifest_reference.json` - file.
  5. Zip your fills to an `asset.zip` - file.
  6. You are now ready to upload `asset.zip` - file and start registration of your asset.
