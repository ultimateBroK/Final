#!/bin/bash
# clean_spark.sh - Dọn dẹp dự án để bắt đầu lại từ đầu (HDFS workflow)

echo "=== DỌN DẸP DỰ ÁN ==="

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"
DATA_RESULTS="$ROOT_DIR/data/results"

# 1. Xóa các file tạm
echo "Đang xóa các file tạm..."
rm -f "$DATA_PROCESSED"/*_temp.txt
rm -f "$DATA_PROCESSED"/*.txt

# 2. Xóa kết quả đã tải về
echo "Đang xóa kết quả đã tải về..."
rm -f "$DATA_RESULTS"/*

# 3. Xóa log
echo "Đang xóa logs..."
rm -f "$ROOT_DIR/logs"/*.md

# 4. Reset các checkpoint của pipeline
echo "Đang reset checkpoints..."
"$ROOT_DIR/scripts/pipeline/reset_pipeline.sh" all

# 5. Dọn dẹp HDFS (tùy chọn - bỏ comment nếu cần)
# echo "Đang dọn dẹp HDFS..."
# hdfs dfs -rm -r -f /user/spark/hi_large/input 2>/dev/null
# hdfs dfs -rm -r -f /user/spark/hi_large/output_centroids 2>/dev/null
# hdfs dfs -rm -f /user/spark/hi_large/centroids.txt 2>/dev/null

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Project is ready for a fresh run:"
echo "  ./scripts/pipeline/full_pipeline_spark.sh"
