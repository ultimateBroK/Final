#!/bin/bash
# clean_spark.sh - Clean project for fresh start (HDFS workflow)

echo "=== CLEANING PROJECT ==="

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"
DATA_RESULTS="$ROOT_DIR/data/results"

# 1. Remove any temp files
echo "Removing temp files..."
rm -f "$DATA_PROCESSED"/*_temp.txt
rm -f "$DATA_PROCESSED"/*.txt

# 2. Remove downloaded results
echo "Removing downloaded results..."
rm -f "$DATA_RESULTS"/*

# 3. Remove logs
echo "Removing logs..."
rm -f "$ROOT_DIR/logs"/*.md

# 4. Reset pipeline checkpoints
echo "Resetting checkpoints..."
"$ROOT_DIR/scripts/pipeline/reset_pipeline.sh" all

# 5. Clean HDFS (optional - uncomment if needed)
# echo "Cleaning HDFS..."
# hdfs dfs -rm -r -f /user/spark/hi_large/input 2>/dev/null
# hdfs dfs -rm -r -f /user/spark/hi_large/output_centroids 2>/dev/null
# hdfs dfs -rm -f /user/spark/hi_large/centroids.txt 2>/dev/null

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Project is ready for a fresh run:"
echo "  ./scripts/pipeline/full_pipeline_spark.sh"
