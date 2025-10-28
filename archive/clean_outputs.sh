#!/bin/bash
# clean_outputs.sh
# Script để xóa tất cả các output files từ pipeline

echo "=== CLEANING PIPELINE OUTPUTS ==="

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"
DATA_RESULTS="$ROOT_DIR/data/results"

# 1. Local output files
echo "Removing local output files..."
rm -f "$DATA_PROCESSED/hadoop_input.txt"
rm -f "$DATA_PROCESSED/centroids.txt"
rm -f "$DATA_PROCESSED/centroids_new.txt"
rm -f "$DATA_PROCESSED/final_centroids.txt"
rm -f "$DATA_RESULTS/clustered_results.txt"

# 2. HDFS directories
echo "Removing HDFS directories..."
hdfs dfs -rm -r -f /user/hadoop/hi_large/input
hdfs dfs -rm -r -f /user/hadoop/hi_large/output_iter_*
hdfs dfs -rm -f /user/hadoop/hi_large/centroids.txt

echo ""
echo "✅ Cleanup complete!"
echo "You can now run ./scripts/full_pipeline.sh again"
