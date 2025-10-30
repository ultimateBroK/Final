#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 📊 DỰ ÁN: Phân Tích Rửa Tiền — K-means (Polars + Spark)
# BƯỚC 5/7: TẢI KẾT QUẢ TỪ HDFS VỀ LOCAL
# ─────────────────────────────────────────────────────────────────────────────
# Mục tiêu: Gộp (getmerge) centroids từ HDFS về 01_data/results/final_centroids.txt
# I/O:
#   - Input (HDFS): /user/spark/hi_large/output_centroids/
#   - Output(local): 01_data/results/final_centroids.txt
# Cách chạy nhanh:
#   bash 02_scripts/spark/download_from_hdfs.sh
# Ghi chú: Yêu cầu bước 4 đã chạy xong và có thư mục output trên HDFS.

set -euo pipefail

echo "=== TẢI KẾT QUẢ TỪ HDFS ==="

# Xác định đường dẫn thư mục
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_RESULTS="$ROOT_DIR/01_data/results"

# Cấu hình HDFS
HDFS_BASE="/user/spark/hi_large"
HDFS_OUTPUT="$HDFS_BASE/output_centroids"

# Kiểm tra HDFS có đang chạy không
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "HDFS không thể truy cập."
    exit 1
fi

# Kiểm tra kết quả có tồn tại trong HDFS không
if ! hdfs dfs -test -e "$HDFS_OUTPUT" 2>/dev/null; then
    echo "Không tìm thấy kết quả trong HDFS: $HDFS_OUTPUT"
    echo "   Vui lòng chạy PySpark job trước: ./02_scripts/spark/run_spark.sh"
    exit 1
fi

echo "Đã tìm thấy kết quả trong HDFS"
echo ""

# Tạo thư mục results nếu chưa có
mkdir -p "$DATA_RESULTS"

# Tải tâm cụm cuối cùng
echo "Đang tải tâm cụm cuối cùng..."
echo "  Từ: $HDFS_OUTPUT"
echo "  Đến: $DATA_RESULTS/final_centroids.txt"

# Xóa file local cũ
rm -f "$DATA_RESULTS/final_centroids.txt"

# Gộp tất cả các phần từ HDFS
hdfs dfs -getmerge "$HDFS_OUTPUT" "$DATA_RESULTS/final_centroids.txt"

if [ $? -ne 0 ]; then
    echo "Thất bại khi tải tâm cụm"
    exit 1
fi

echo "Đã tải tâm cụm cuối cùng"
echo ""

# Hiển thị thông tin file
if [ -f "$DATA_RESULTS/final_centroids.txt" ]; then
    FILE_SIZE=$(du -h "$DATA_RESULTS/final_centroids.txt" | cut -f1)
    LINE_COUNT=$(wc -l < "$DATA_RESULTS/final_centroids.txt")
    echo "Thông tin file local:"
    echo "  Kích thước: $FILE_SIZE"
    echo "  Số dòng (cụm): $LINE_COUNT"
    echo ""
    echo "Xem trước:"
    head -n 5 "$DATA_RESULTS/final_centroids.txt"
fi

echo ""
echo "Hoàn thành tải xuống!"
echo ""
echo "Bước tiếp theo:"
echo "  1. Gán cụm: python $ROOT_DIR/02_scripts/polars/assign_clusters.py"
echo "  2. Phân tích kết quả: python $ROOT_DIR/02_scripts/polars/analyze.py"
