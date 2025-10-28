#!/bin/bash
# download_from_hdfs.sh - Tải kết quả từ HDFS để phân tích local

echo "=== TẢI KẾT QUẢ TỪ HDFS ==="

# Xác định đường dẫn thư mục
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"

# Cấu hình HDFS
HDFS_BASE="/user/spark/hi_large"
HDFS_OUTPUT="$HDFS_BASE/output_centroids"

# Kiểm tra HDFS có đang chạy không
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "❌ HDFS không thể truy cập."
    exit 1
fi

# Kiểm tra kết quả có tồn tại trong HDFS không
if ! hdfs dfs -test -e "$HDFS_OUTPUT" 2>/dev/null; then
    echo "❌ Không tìm thấy kết quả trong HDFS: $HDFS_OUTPUT"
    echo "   Vui lòng chạy PySpark job trước: ./scripts/spark/run_spark.sh"
    exit 1
fi

echo "✅ Đã tìm thấy kết quả trong HDFS"
echo ""

# Tải tâm cụm cuối cùng
echo "Đang tải tâm cụm cuối cùng..."
echo "  Từ: $HDFS_OUTPUT"
echo "  Đến: $DATA_PROCESSED/final_centroids.txt"

# Xóa file local cũ
rm -f "$DATA_PROCESSED/final_centroids.txt"

# Gộp tất cả các phần từ HDFS
hdfs dfs -getmerge "$HDFS_OUTPUT" "$DATA_PROCESSED/final_centroids.txt"

if [ $? -ne 0 ]; then
    echo "❌ Thất bại khi tải tâm cụm"
    exit 1
fi

echo "✅ Đã tải tâm cụm cuối cùng"
echo ""

# Hiển thị thông tin file
if [ -f "$DATA_PROCESSED/final_centroids.txt" ]; then
    FILE_SIZE=$(du -h "$DATA_PROCESSED/final_centroids.txt" | cut -f1)
    LINE_COUNT=$(wc -l < "$DATA_PROCESSED/final_centroids.txt")
    echo "Thông tin file local:"
    echo "  Kích thước: $FILE_SIZE"
    echo "  Số dòng (cụm): $LINE_COUNT"
    echo ""
    echo "Xem trước:"
    head -n 5 "$DATA_PROCESSED/final_centroids.txt"
fi

echo ""
echo "✅ Hoàn thành tải xuống!"
echo ""
echo "Bước tiếp theo:"
echo "  1. Gán cụm: cd $ROOT_DIR/scripts/polars && python assign_clusters_polars.py"
echo "  2. Phân tích kết quả: cd $ROOT_DIR/scripts/polars && python analyze_polars.py"
