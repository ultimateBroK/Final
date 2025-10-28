#!/bin/bash
# setup_hdfs.sh - Thiết lập thư mục HDFS và upload dữ liệu cho pipeline Spark

echo "=== THIẾT LẬP HDFS CHO PYSPARK K-MEANS ==="

# Xác định đường dẫn thư mục
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"

# Cấu hình HDFS
HDFS_BASE="/user/spark/hi_large"

# Kiểm tra HDFS có đang chạy không
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "❌ HDFS không thể truy cập. Vui lòng khởi động HDFS trước."
    echo ""
    echo "Để khởi động HDFS:"
    echo "  1. Format namenode (chỉ lần đầu): hdfs namenode -format"
    echo "  2. Khởi động HDFS: start-dfs.sh"
    echo "  3. Kiểm tra trạng thái: jps"
    exit 1
fi

echo "✅ HDFS có thể truy cập"
echo ""

# Kiểm tra file dữ liệu tạm có tồn tại không
INPUT_TEMP="$DATA_PROCESSED/hadoop_input_temp.txt"
CENTROIDS_TEMP="$DATA_PROCESSED/centroids_temp.txt"

if [ ! -f "$INPUT_TEMP" ]; then
    echo "❌ Không tìm thấy file đầu vào tạm: $INPUT_TEMP"
    echo "   Vui lòng chạy chuẩn bị dữ liệu trước:"
    echo "   cd $ROOT_DIR/scripts/polars && python prepare_polars.py"
    exit 1
fi

if [ ! -f "$CENTROIDS_TEMP" ]; then
    echo "❌ Không tìm thấy file tâm cụm tạm: $CENTROIDS_TEMP"
    echo "   Vui lòng chạy khởi tạo tâm cụm trước:"
    echo "   cd $ROOT_DIR/scripts/polars && python init_centroids.py"
    exit 1
fi

echo "✅ Đã tìm thấy file dữ liệu tạm"
echo ""

# Tạo thư mục HDFS
echo "Đang tạo thư mục HDFS..."
hdfs dfs -mkdir -p "$HDFS_BASE/input"
hdfs dfs -mkdir -p "$HDFS_BASE/output"

# Dọn dẹp dữ liệu cũ
echo "Đang dọn dẹp dữ liệu cũ trong HDFS..."
hdfs dfs -rm -f "$HDFS_BASE/input/*" 2>/dev/null
hdfs dfs -rm -f "$HDFS_BASE/centroids.txt" 2>/dev/null
hdfs dfs -rm -r -f "$HDFS_BASE/output_centroids" 2>/dev/null

# Upload dữ liệu đầu vào
echo ""
echo "Đang upload dữ liệu đầu vào lên HDFS..."
echo "  Nguồn: $INPUT_TEMP"
echo "  Đích: $HDFS_BASE/input/hadoop_input.txt"
hdfs dfs -put "$INPUT_TEMP" "$HDFS_BASE/input/hadoop_input.txt"

if [ $? -ne 0 ]; then
    echo "❌ Thất bại khi upload dữ liệu đầu vào"
    exit 1
fi

# Upload tâm cụm
echo ""
echo "Đang upload tâm cụm lên HDFS..."
echo "  Nguồn: $CENTROIDS_TEMP"
echo "  Đích: $HDFS_BASE/centroids.txt"
hdfs dfs -put "$CENTROIDS_TEMP" "$HDFS_BASE/centroids.txt"

if [ $? -ne 0 ]; then
    echo "❌ Thất bại khi upload tâm cụm"
    exit 1
fi

# Xóa file tạm sau khi upload thành công (KHÔNG lưu dữ liệu local)
echo ""
echo "Đang dọn dẹp file tạm..."
rm -f "$INPUT_TEMP" "$CENTROIDS_TEMP"
echo "✅ Đã xóa file tạm (dữ liệu chỉ còn trên HDFS)"

# Xác minh upload
echo ""
echo "Đang xác minh upload..."
INPUT_SIZE=$(hdfs dfs -du -h "$HDFS_BASE/input/hadoop_input.txt" | awk '{print $1 " " $2}')
CENTROIDS_SIZE=$(hdfs dfs -du -h "$HDFS_BASE/centroids.txt" | awk '{print $1 " " $2}')

echo "  ✅ Dữ liệu đầu vào: $INPUT_SIZE"
echo "  ✅ Tâm cụm: $CENTROIDS_SIZE"

# Hiển thị cấu trúc thư mục HDFS
echo ""
echo "Cấu trúc thư mục HDFS:"
hdfs dfs -ls -R "$HDFS_BASE"

echo ""
echo "==================================="
echo "✅ HOÀN TẤT THIẾT LẬP HDFS!"
echo "==================================="
echo ""
echo "Đường dẫn HDFS:"
echo "  Đầu vào: hdfs://localhost:9000$HDFS_BASE/input/hadoop_input.txt"
echo "  Tâm cụm: hdfs://localhost:9000$HDFS_BASE/centroids.txt"
echo "  Đầu ra: hdfs://localhost:9000$HDFS_BASE/output_centroids"
echo ""
echo "Bước tiếp theo: Chạy PySpark job"
echo "  ./scripts/spark/run_spark.sh"
