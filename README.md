# Distributed Compliance Ledger (DCL) Data Repository

## Overview
This repository contains data exported from the Distributed Compliance Ledger (DCL) in JSON format. The DCL is a cryptographically secure distributed network that allows device manufacturers, test houses, and certification centers to publish and verify information about IoT devices. This repository aims to facilitate academic research and provide accessible DCL data for further analysis and study.

## Data Quality and Integrity
To ensure the integrity and quality of the data, I have implemented a GitHub Action that validates all JSON files for basic correctness. This process checks that all JSON files are well-formed, ensuring that the data can be reliably used for research and analysis.

[![Validate JSON](https://github.com/alexanderkent/dcl_data/actions/workflows/validate-json.yml/badge.svg)](https://github.com/alexanderkent/dcl_data/actions/workflows/validate-json.yml)

## Repository Structure
The data is organized into various directories based on the type of information:

- **data/model/vendor-models/**: Contains JSON files of vendor models for each Vendor ID (VID).
- **data/model/all-versions/**: Contains JSON files of all model versions for each VID and Product ID (PID).
- **data/model/model-version/**: Contains JSON files of specific model versions identified by VID, PID, and Software Version.

## Data Extraction Script
The repository includes a script (`export_dcl_data.sh`) to automate the process of fetching and organizing the data. The script performs the following tasks:

1. **Creates Necessary Directories**: Initializes directories to store the fetched data.
2. **Fetches Vendor Information**: Retrieves all vendor information and stores it in JSON files.
3. **Creates Lookup Files**: Generates lookup files for vendor IDs and legal names.
4. **Fetches Validator Information**: Retrieves information about validators and stores it in JSON files.
5. **Fetches Vendor Models**: Retrieves and stores vendor models for each VID.
6. **Fetches All Models**: Retrieves and stores all model information in paginated JSON files.
7. **Maps VIDs to PIDs**: Creates a mapping of Vendor IDs to Product IDs.
8. **Fetches All Model Versions**: Retrieves and stores all model versions based on VID and PID.
9. **Fetches Specific Model Versions**: Retrieves and stores specific model versions based on VID, PID, and Software Version.

## Script Usage
To run the script and fetch the data, use the following command:
```bash
./export_dcl_data.sh
```
Ensure that the dcld binary and jq are installed and accessible on your system. The script requires a fully synced DCL node to date to function correctly.

### License
This repository is licensed under the MIT License. See the LICENSE file for more information.