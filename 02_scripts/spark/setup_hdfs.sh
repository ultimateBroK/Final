#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 📊 DỰ ÁN: Phân Tích Rửa Tiền — K-means (Polars + Spark)
# BƯỚC 3/7: THIẾT LẬP HDFS & UPLOAD DỮ LIỆU
# ─────────────────────────────────────────────────────────────────────────────
# Mục tiêu: Tạo thư mục HDFS, dọn dẹp dữ liệu cũ, upload dữ liệu chuẩn hoá
#            (temp local) lên HDFS và (mặc định) xoá temp local.
# I/O:
#   - Input(local tạm): 01_data/processed/hadoop_input_temp.txt (~33GB)
#   - Output (HDFS)   : /user/spark/hi_large/input/hadoop_input.txt
# Cách chạy nhanh:
#   bash 02_scripts/spark/setup_hdfs.sh [--no-delete]
# Tham số:
#   --input <path>     : đường dẫn file tạm local
#   --hdfs-base <dir>  : thư mục gốc HDFS (mặc định /user/spark/hi_large)
#   --no-delete        : KHÔNG xoá file tạm sau khi upload

set -euo pipefail

echo "=== BƯỚC 3: THIẾT LẬP HDFS CHO PYSPARK K-MEANS ==="

usage() {
  echo "Cách dùng: $0 [--input <local_temp_path>] [--hdfs-base <hdfs_base_dir>] [--no-delete]"
  echo "  --input       Đường dẫn file tạm local (mặc định: 01_data/processed/hadoop_input_temp.txt)"
  echo "  --hdfs-base   Thư mục gốc trên HDFS (mặc định: /user/spark/hi_large)"
  echo "  --no-delete   Không xóa file tạm local sau khi upload"
}

# Xác định đường dẫn thư mục
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/01_data/processed"

# Cấu hình HDFS (có thể override qua CLI)
HDFS_BASE="/user/spark/hi_large"

# Kiểm tra HDFS có đang chạy không
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "HDFS không thể truy cập. Vui lòng khởi động HDFS trước."
    echo ""
    echo "Để khởi động HDFS:"
    echo "  1. Format namenode (chỉ lần đầu): hdfs namenode -format"
    echo "  2. Khởi động HDFS: start-dfs.sh"
    echo "  3. Kiểm tra trạng thái: jps"
    exit 1
fi

echo "HDFS có thể truy cập"
echo ""

# Parse CLI
INPUT_TEMP="$DATA_PROCESSED/hadoop_input_temp.txt"
DELETE_LOCAL=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --input)
      INPUT_TEMP="$2"; shift 2 ;;
    --hdfs-base)
      HDFS_BASE="$2"; shift 2 ;;
    --no-delete)
      DELETE_LOCAL=false; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "Tham số không hợp lệ: $1"; usage; exit 1 ;;
  esac
done

# Kiểm tra file dữ liệu tạm có tồn tại không

if [ ! -f "$INPUT_TEMP" ]; then
    echo "Không tìm thấy tệp đầu vào tạm: $INPUT_TEMP"
    echo "   Vui lòng chạy chuẩn bị dữ liệu trước:"
    echo "   python $ROOT_DIR/02_scripts/polars/02_prepare_polars.py"
    exit 1
fi

echo "Đã tìm thấy tệp dữ liệu tạm"
echo ""

# Tạo thư mục HDFS
echo "Đang tạo thư mục HDFS..."
hdfs dfs -mkdir -p "$HDFS_BASE/input"
hdfs dfs -mkdir -p "$HDFS_BASE/output"

# Dọn dẹp dữ liệu cũ
echo "Đang dọn dẹp dữ liệu cũ trong HDFS..."
hdfs dfs -rm -f "$HDFS_BASE/input/*" 2>/dev/null
hdfs dfs -rm -r -f "$HDFS_BASE/output_centroids" 2>/dev/null

# Upload dữ liệu đầu vào
echo ""
echo "Đang tải dữ liệu đầu vào lên HDFS..."
echo "  Nguồn: $INPUT_TEMP"
echo "  Đích: $HDFS_BASE/input/hadoop_input.txt"
hdfs dfs -put "$INPUT_TEMP" "$HDFS_BASE/input/hadoop_input.txt"

if [ $? -ne 0 ]; then
    echo "Thất bại khi tải dữ liệu đầu vào"
    exit 1
fi

# Xóa file tạm sau khi upload thành công (tuỳ chọn)
echo ""
if [ "$DELETE_LOCAL" = true ]; then
  echo "Đang dọn dẹp tệp tạm..."
  rm -f "$INPUT_TEMP"
  echo "Đã xóa tệp tạm (dữ liệu chỉ còn trên HDFS)"
else
  echo "Giữ lại tệp tạm local theo yêu cầu (--no-delete)"
fi
echo "MLlib sẽ tự động khởi tạo tâm cụm với k-means++"

# Xác minh upload
echo ""
echo "Đang xác minh upload..."
INPUT_SIZE=$(hdfs dfs -du -h "$HDFS_BASE/input/hadoop_input.txt" | awk '{print $1 " " $2}')

echo "  Dữ liệu đầu vào: $INPUT_SIZE"

# Hiển thị cấu trúc thư mục HDFS
echo ""
echo "Cấu trúc thư mục HDFS:"
hdfs dfs -ls -R "$HDFS_BASE"

echo ""
echo "==================================="
echo "HOÀN TẤT THIẾT LẬP HDFS!"
echo "==================================="
echo ""
echo "Đường dẫn HDFS:"
echo "  Đầu vào: hdfs://localhost:9000$HDFS_BASE/input/hadoop_input.txt"
echo "  Đầu ra: hdfs://localhost:9000$HDFS_BASE/output_centroids"
echo ""
echo "Bước tiếp theo (Bước 4): Chạy K-means với MLlib"
echo "  bash ./02_scripts/spark/run_spark.sh"
echo ""
echo "Ghi chú: MLlib dùng k-means++ để khởi tạo centroids tự động"
