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

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "Processing reports with timestamp: $TIMESTAMP"

# Part 1: Process PNG Reports
for arch in $ARCHS; do
    ARTIFACT_DIR="${ARTIFACT_PREFIX}-$arch"
    CURRENT_REPORT_DIR="${REPORT_DIR}/$arch"
    
    # Create report dir if it doesn't exist
    mkdir -p "$CURRENT_REPORT_DIR/"

    for metric in $METRICS; do
        if [ -f "$ARTIFACT_DIR/$metric.png" ]; then
            cp "$ARTIFACT_DIR/$metric.png" "$CURRENT_REPORT_DIR/${metric}_$TIMESTAMP.png"
            cp "$ARTIFACT_DIR/$metric.png" "$CURRENT_REPORT_DIR/${metric}_latest.png"
            echo "Report saved as $CURRENT_REPORT_DIR/${metric}_latest.png"
        else
            echo "Warning: PNG report not found at $ARTIFACT_DIR/$metric.png (skipping)"
        fi
    done
done

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

# Read existing reports.json if it exists, otherwise create an empty object
if [ -f "$DOCS_DIR/reports.json" ]; then
    EXISTING_REPORTS_JSON=$(cat "$DOCS_DIR/reports.json")
else
    EXISTING_REPORTS_JSON='{}'
fi

# Add the new report to the existing reports with the timestamp as key
ALL_REPORTS_JSON=$(echo "$EXISTING_REPORTS_JSON" | jq --argjson new_report "$NEW_REPORT_JSON" --arg timestamp "$TIMESTAMP" '. + {($timestamp): $new_report}')

# Update 'latest' key
ALL_REPORTS_JSON=$(echo "$ALL_REPORTS_JSON" | jq --argjson new_report "$NEW_REPORT_JSON" '. + {latest: $new_report}')

# Save to file
echo "$ALL_REPORTS_JSON" | jq '.' > "$DOCS_DIR/reports.json"
echo "Combined reports saved to $DOCS_DIR/reports.json"
