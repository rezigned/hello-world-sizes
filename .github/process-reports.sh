#!/usr/bin/env bash
set -e

# NOTE: For local testing, set ARTIFACT_PREFIX to "build/reports" and remove 
#the "-$arch" suffix from the loop

# Default values
ARTIFACT_PREFIX=${ARTIFACT_PREFIX:-"all-reports"}
REPORT_DIR=${REPORT_DIR:-".github/reports"}
DOCS_DIR=${DOCS_DIR:-"docs"}
ARCHS=${ARCHS:-"arm64 amd64"}
METRICS=${METRICS:-"binary_size memory_usage"}

# Ensure directories exist
mkdir -p "$DOCS_DIR"

# Get the last commit time of flake.lock in UTC
# This ensures the report key is based on dependency state, not build time.
TIMESTAMP=$(TZ=UTC git log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%ad -- flake.lock 2>/dev/null)

if [ -z "$TIMESTAMP" ]; then
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "Warning: Could not get flake.lock commit time, falling back to current time: $TIMESTAMP"
else
    echo "Using timestamp from flake.lock: $TIMESTAMP"
fi

# # Part 1: Process PNG Reports
# for arch in $ARCHS; do
#     ARTIFACT_DIR="${ARTIFACT_PREFIX}-$arch"
#     CURRENT_REPORT_DIR="${REPORT_DIR}/$arch"
    
#     # Create report dir if it doesn't exist
#     mkdir -p "$CURRENT_REPORT_DIR/"

#     for metric in $METRICS; do
#         if [ -f "$ARTIFACT_DIR/$metric.png" ]; then
#             cp "$ARTIFACT_DIR/$metric.png" "$CURRENT_REPORT_DIR/${metric}_$TIMESTAMP.png"
#             cp "$ARTIFACT_DIR/$metric.png" "$CURRENT_REPORT_DIR/${metric}_latest.png"
#             echo "Report saved as $CURRENT_REPORT_DIR/${metric}_latest.png"
#         else
#             echo "Warning: PNG report not found at $ARTIFACT_DIR/$metric.png (skipping)"
#         fi
#     done
# done

# Part 2: Process and combine JSON reports
NEW_REPORT_JSON='{"binary_size": [], "memory_usage": []}'

for arch in $ARCHS; do
    ARTIFACT_DIR="${ARTIFACT_PREFIX}-$arch"
    for metric in $METRICS; do
        JSON_FILE="$ARTIFACT_DIR/$metric.json"
        
        if [ -f "$JSON_FILE" ]; then
            echo "Processing $JSON_FILE for $arch"
            if ! command -v jq &> /dev/null; then
                echo "Error: jq is required but not installed."
                exit 1
            fi

            # Read JSON and add 'arch' field to each record
            # We use 'map' to ensure the output is a single JSON array
            JSON_WITH_ARCH=$(jq --arg arch "$arch" 'map(. + {arch: $arch})' "$JSON_FILE")
            
            # Merge with existing data in NEW_REPORT_JSON
            NEW_REPORT_JSON=$(echo "$NEW_REPORT_JSON" | jq --argjson new_data "$JSON_WITH_ARCH" --arg metric "$metric" '.[$metric] += $new_data')
        else
            echo "Warning: JSON report not found at $JSON_FILE (skipping)"
        fi
    done
done

# Individual reports folder
DATA_DIR="$DOCS_DIR/reports"
mkdir -p "$DATA_DIR"

# Save binary data for this specific timestamp
echo "$NEW_REPORT_JSON" | jq '.' > "$DATA_DIR/${TIMESTAMP}.json"
echo "Binary report data saved to $DATA_DIR/${TIMESTAMP}.json"

# Update 'latest.json'
echo "$NEW_REPORT_JSON" | jq '.' > "$DATA_DIR/latest.json"

# Update the main reports.json index (list of timestamps only)
if [ -f "$DOCS_DIR/reports.json" ]; then
    EXISTING_TIMESTAMPS=$(cat "$DOCS_DIR/reports.json")
else
    EXISTING_TIMESTAMPS='[]'
fi

# Add the new timestamp to the list if not already present, and sort descending
ALL_TIMESTAMPS=$(echo "$EXISTING_TIMESTAMPS" | jq --arg ts "$TIMESTAMP" '. + [$ts] | unique | sort | reverse')

# Save the index to file
echo "$ALL_TIMESTAMPS" | jq '.' > "$DOCS_DIR/reports.json"
echo "Updated $DOCS_DIR/reports.json index with $(echo "$ALL_TIMESTAMPS" | jq 'length') timestamps."
