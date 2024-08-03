#!/bin/bash

# Define variables
ROOT_CMD="/root/dcld"
DATA_DIR="./data"
MODEL_DIR="$DATA_DIR/model"
VENDOR_MODELS_DIR="$MODEL_DIR/vendor-models"
ALL_VERSIONS_DIR="$MODEL_DIR/all-versions"
MODEL_VERSION_DIR="$MODEL_DIR/model-version"

# Function to create directories
create_directories() {
    mkdir -p "$VENDOR_MODELS_DIR" "$ALL_VERSIONS_DIR" "$MODEL_VERSION_DIR"
}

# Function to fetch paginated data
fetch_paginated_data() {
    local cmd="$1"
    local output_file="$2"
    local page=1

    while true; do
        $cmd --page $page | jq > "${output_file}-${page}.json"
        next_key=$(jq -r '.pagination.next_key' "${output_file}-${page}.json")
        [[ "$next_key" == "null" ]] && break
        ((page++))
    done
}

# Function to fetch validator info
fetch_validator_info() {
    local queries=("all-disabled-nodes" "all-last-powers" "all-nodes" "all-proposed-disable-nodes" "all-rejected-disable-nodes")
    for query in "${queries[@]}"; do
        $ROOT_CMD query validator $query | jq > "$DATA_DIR/validator-$query.json"
    done
}

# Function to fetch vendor models
fetch_vendor_models() {
    while read -r VID; do
        OUTPUT=$($ROOT_CMD query model vendor-models --vid $VID | jq .)
        [[ "${OUTPUT,,}" != *"not found"* ]] && echo "$OUTPUT" > "$VENDOR_MODELS_DIR/vendor-models-$VID.json"
    done < "$DATA_DIR/all-vendors-vid.txt"
    echo "Created $(find $VENDOR_MODELS_DIR -maxdepth 1 -type f | wc -l) files."
}

# Function to create VID to PID mapping
create_vid_pid_map() {
    echo "{}" > "$DATA_DIR/vid_to_pid_map.json"
    for file in $MODEL_DIR/all-models-*.json; do
        jq -c '.model[]' "$file" | while read -r obj; do
            vid=$(echo "$obj" | jq -r '.vid')
            pid=$(echo "$obj" | jq -r '.pid')
            existing_pids=$(jq -r ".[\"$vid\"]" "$DATA_DIR/vid_to_pid_map.json")
            if [ "$existing_pids" == "null" ]; then
                jq ". + {\"$vid\": [$pid]}" "$DATA_DIR/vid_to_pid_map.json" > temp.json && mv temp.json "$DATA_DIR/vid_to_pid_map.json"
            else
                updated_pids=$(echo "$existing_pids" | jq -c ". + [$pid]")
                jq ".[\"$vid\"] = $updated_pids" "$DATA_DIR/vid_to_pid_map.json" > temp.json && mv temp.json "$DATA_DIR/vid_to_pid_map.json"
            fi
        done
    done
}

# Function to fetch all model versions
fetch_all_model_versions() {
    jq -r 'to_entries | .[] | "\(.key) \(.value[])"' "$DATA_DIR/vid_to_pid_map.json" | while read -r VID PID; do
        OUTPUT=$($ROOT_CMD query model all-model-versions --vid $VID --pid $PID)
        [[ ! "${OUTPUT,,}" =~ "not found" ]] && echo "$OUTPUT" | jq > "$ALL_VERSIONS_DIR/all-model-version-$VID-$PID.json"
    done
}

# Function to fetch model versions
fetch_model_versions() {
    for file in $ALL_VERSIONS_DIR/all-model-version-*.json; do
        VID=$(jq -r 'select(.vid != null) | .vid' "$file")
        PID=$(jq -r 'select(.pid != null) | .pid' "$file")
        jq -r 'select(.softwareVersions != null) | .softwareVersions[]' "$file" | while read -r SOFTWARE_VERSION; do
            OUTPUT=$($ROOT_CMD query model model-version --vid $VID --pid $PID --softwareVersion $SOFTWARE_VERSION)
            [[ ! "${OUTPUT,,}" =~ "not found" ]] && echo "$OUTPUT" | jq > "$MODEL_VERSION_DIR/model-version-$VID-$PID-$SOFTWARE_VERSION.json"
        done
    done
}

# Main execution
create_directories

$ROOT_CMD status --node tcp://localhost:26657 | jq > "$DATA_DIR/status.json"

echo "Fetching vendor info..."
fetch_paginated_data "$ROOT_CMD query vendorinfo all-vendors" "$DATA_DIR/all-vendors"

echo "Creating vendor info lookup files..."
cat $DATA_DIR/all-vendors-*.json | jq -r '.vendorInfo[] | select(.vendorID != null) | .vendorID' | sort > "$DATA_DIR/all-vendors-vid.txt"
cat $DATA_DIR/all-vendors-*.json | jq -r '.vendorInfo[] | select(.companyLegalName != null) | .companyLegalName' | sort > "$DATA_DIR/all-vendors-legal-name.txt"

echo "Fetching validator info..."
fetch_validator_info

echo "Fetching vendor models..."
fetch_vendor_models

echo "Fetching all models..."
fetch_paginated_data "$ROOT_CMD query model all-models" "$MODEL_DIR/all-models"

echo "VID to PID Mapping"
create_vid_pid_map

echo "Fetching all model versions..."
fetch_all_model_versions

echo "Fetching model versions..."
fetch_model_versions

echo "All data fetching completed."
