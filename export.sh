#!/bin/bash

# Create necessary directories
mkdir -p data/model/vendor-models/
mkdir -p data/model/all-versions/
mkdir -p data/model/model-version/

# Fetch Vendor Info
echo "Fetching vendor info..."
page=1
while true; do
    /root/dcld query vendorinfo all-vendors --page $page | jq > "all-vendors-$page.json"
    next_key=$(jq -r '.pagination.next_key' "all-vendors-$page.json")
    total=$(jq -r '.pagination.total' "all-vendors-$page.json")
    if [[ "$next_key" == "null" ]]; then
        echo "No more pages to fetch."
        break
    fi
    ((page++))
done

# Create vendor info lookup files
echo "Creating vendor info lookup files..."
cat all-vendors-*.json | jq -r '.vendorInfo[] | select(.vendorID != null) | .vendorID' | sort > data/all-vendors-vid.txt
cat all-vendors-*.json | jq -r '.vendorInfo[] | select(.companyLegalName != null) | .companyLegalName' | sort > data/all-vendors-legal-name.txt

# Move all-vendors JSON files to data/
mv all-vendors-* data/

# Fetch Validators
echo "Fetching validator info..."
/root/dcld query validator all-disabled-nodes | jq > data/validator-all-disabled-node.json
/root/dcld query validator all-last-powers | jq > data/validator-all-last-powers.json
/root/dcld query validator all-nodes | jq > data/validator-all-nodes.json
/root/dcld query validator all-proposed-disable-nodes | jq > data/validator-all-proposed-disable-nodes.json
/root/dcld query validator all-rejected-disable-nodes | jq > data/validator-all-rejected-disable-nodes.json

# Fetch Vendor Models for each VID
echo "Fetching vendor models..."
while read -r VID; do
    OUTPUT=$(/root/dcld query model vendor-models --vid $VID | jq .)
    if [[ "${OUTPUT,,}" != *"not found"* ]]; then
        echo "$OUTPUT" > "data/model/vendor-models/vendor-models-$VID.json"
    fi
done < data/all-vendors-vid.txt

FILE_COUNT=$(find data/model/vendor-models/ -maxdepth 1 -type f | wc -l)
echo "Created $FILE_COUNT files."

# Fetch All Models
echo "Fetching all models..."
page=1
while true; do
    /root/dcld query model all-models --page $page | jq > "data/model/all-models-$page.json"
    next_key=$(jq -r '.pagination.next_key' "data/model/all-models-$page.json")
    total=$(jq -r '.pagination.total' "data/model/all-models-$page.json")
    if [[ "$next_key" == "null" ]]; then
        echo "No more pages to fetch."
        break
    fi
    ((page++))
done

# VID to PID Mapping
echo "VID to PID Mapping"
echo "{}" > vid_to_pid_map.json

# Loop over each JSON file
for file in data/model/all-models-*.json; do
# Use jq to iterate over each 'model' object in the JSON array
jq -c '.model[]' $file | while read -r obj; do
    # Extract the vid and pid from each object
    vid=$(echo $obj | jq -r '.vid')
    pid=$(echo $obj | jq -r '.pid')

    # Check if this vid already has an entry in vid_to_pid_map.json
    existing_pids=$(jq -r ".\"$vid\"" vid_to_pid_map.json)
    
    # If this is a new vid, create an entry with an array containing this pid
    if [ "$existing_pids" == "null" ]; then
    jq ". + {\"$vid\": [$pid]}" vid_to_pid_map.json > temp.json && mv temp.json vid_to_pid_map.json
    else
    # Otherwise, append this pid to the existing array for this vid
    updated_pids=$(echo $existing_pids | jq -c ". + [$pid]")
    jq ".\"$vid\" = $updated_pids" vid_to_pid_map.json > temp.json && mv temp.json vid_to_pid_map.json
    fi
done
done
mv vid_to_pid_map.json data/vid_to_pid_map.json


# Fetch All Model Versions
echo "Fetching all model versions..."
jq -r 'to_entries | .[] | "\(.key) \(.value[])"' data/vid_to_pid_map.json | while read -r VID PID; do
    OUTPUT=$(/root/dcld query model all-model-versions --vid $VID --pid $PID)
    if [[ ! "${OUTPUT,,}" =~ "not found" ]]; then
        echo "$OUTPUT" | jq > "data/model/all-versions/all-model-version-$VID-$PID.json"
    fi
done

# Fetch Model Version
echo "Fetching model versions..."
for file in data/model/all-versions/all-model-version-*.json; do
    VID=$(jq -r 'select(.vid != null) | .vid' "$file")
    PID=$(jq -r 'select(.pid != null) | .pid' "$file")
    softwareVersions=$(jq -r 'select(.softwareVersions != null) | .softwareVersions[]' "$file")
    for SOFTWARE_VERSION in $softwareVersions; do
        OUTPUT=$(/root/dcld query model model-version --vid $VID --pid $PID --softwareVersion $SOFTWARE_VERSION)
        if [[ ! "${OUTPUT,,}" =~ "not found" ]]; then
            echo "$OUTPUT" | jq > "data/model/model-version/model-version-$VID-$PID-$SOFTWARE_VERSION.json"
        fi
    done
done

echo "All data feching completed."
