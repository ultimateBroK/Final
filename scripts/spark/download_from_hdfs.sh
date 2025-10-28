#!/bin/bash
# download_from_hdfs.sh - Download results from HDFS for local analysis

echo "=== Downloading results from HDFS ==="

# Resolve directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"

# HDFS Configuration
HDFS_BASE="/user/spark/hi_large"
HDFS_OUTPUT="$HDFS_BASE/output_centroids"

# Check if HDFS is running
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "❌ HDFS is not accessible."
    exit 1
fi

# Check if output exists in HDFS
if ! hdfs dfs -test -e "$HDFS_OUTPUT" 2>/dev/null; then
    echo "❌ Output not found in HDFS: $HDFS_OUTPUT"
    echo "   Please run the PySpark job first: ./scripts/spark/run_spark.sh"
    exit 1
fi

echo "✅ Output found in HDFS"
echo ""

# Download final centroids
echo "Downloading final centroids..."
echo "  From: $HDFS_OUTPUT"
echo "  To: $DATA_PROCESSED/final_centroids.txt"

# Remove old local file
rm -f "$DATA_PROCESSED/final_centroids.txt"

# Merge all parts from HDFS
hdfs dfs -getmerge "$HDFS_OUTPUT" "$DATA_PROCESSED/final_centroids.txt"

if [ $? -ne 0 ]; then
    echo "❌ Failed to download centroids"
    exit 1
fi

echo "✅ Downloaded final centroids"
echo ""

# Show file info
if [ -f "$DATA_PROCESSED/final_centroids.txt" ]; then
    FILE_SIZE=$(du -h "$DATA_PROCESSED/final_centroids.txt" | cut -f1)
    LINE_COUNT=$(wc -l < "$DATA_PROCESSED/final_centroids.txt")
    echo "Local file info:"
    echo "  Size: $FILE_SIZE"
    echo "  Lines (clusters): $LINE_COUNT"
    echo ""
    echo "Preview:"
    head -n 5 "$DATA_PROCESSED/final_centroids.txt"
fi

echo ""
echo "✅ Download completed!"
echo ""
echo "Next steps:"
echo "  1. Assign clusters: cd $ROOT_DIR/scripts/polars && python assign_clusters_polars.py"
echo "  2. Analyze results: cd $ROOT_DIR/scripts/polars && python analyze_polars.py"
