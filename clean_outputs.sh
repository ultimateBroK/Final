#!/bin/bash
# clean_outputs.sh
# Script để xóa tất cả các output files từ pipeline

echo "=== CLEANING PIPELINE OUTPUTS ==="

# 1. Local output files
echo "Removing local output files..."
rm -f hadoop_input.txt
rm -f centroids.txt
rm -f centroids_new.txt
rm -f final_centroids.txt
rm -f clustered_results.txt

# 2. HDFS directories
echo "Removing HDFS directories..."
hdfs dfs -rm -r -f /user/hadoop/hi_large/input
hdfs dfs -rm -r -f /user/hadoop/hi_large/output_iter_*
hdfs dfs -rm -f /user/hadoop/hi_large/centroids.txt

echo ""
echo "✅ Cleanup complete!"
echo "You can now run ./full_pipeline.sh again"
