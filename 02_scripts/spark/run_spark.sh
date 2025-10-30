#!/bin/bash
# run_spark.sh - Chạy thuật toán K-means với PySpark trên HDFS

set -euo pipefail

echo "=== PYSPARK K-MEANS VỚI HDFS ==="

# Xác định đường dẫn thư mục
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Thiết lập SPARK_HOME cho Spark được cài đặt qua pip
export SPARK_HOME="$ROOT_DIR/.venv/lib/python3.12/site-packages/pyspark"
export PATH="$SPARK_HOME/bin:$PATH"

# Cấu hình HDFS
HDFS_URI="hdfs://localhost:9000"
HDFS_BASE="/user/spark/hi_large"
HDFS_INPUT="$HDFS_URI$HDFS_BASE/input/hadoop_input.txt"
HDFS_OUTPUT="$HDFS_URI$HDFS_BASE/output_centroids"

# Kiểm tra HDFS có đang chạy không
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "HDFS không thể truy cập. Vui lòng khởi động HDFS trước."
    echo "   Chạy: start-dfs.sh"
    exit 1
fi

# Kiểm tra file đầu vào có tồn tại trong HDFS không
if ! hdfs dfs -test -e "$HDFS_BASE/input/hadoop_input.txt" 2>/dev/null; then
    echo "Không tìm thấy tệp đầu vào trong HDFS: $HDFS_BASE/input/hadoop_input.txt"
    echo "   Vui lòng chạy: ./02_scripts/spark/setup_hdfs.sh"
    exit 1
fi

# Lấy số CPU cores để tối ưu hóa
CPU_CORES=$(nproc)
EXECUTOR_CORES=4
EXECUTOR_INSTANCES=4
DRIVER_MEMORY="8g"
EXECUTOR_MEMORY="8g"

echo "Cấu hình:"
echo "  CPU cores: $CPU_CORES"
echo "  Số executor: $EXECUTOR_INSTANCES"
echo "  Executor cores: $EXECUTOR_CORES"
echo "  Executor memory: $EXECUTOR_MEMORY"
echo "  Driver memory: $DRIVER_MEMORY"
echo ""
echo "Sử dụng MLlib (Catalyst, Tungsten, k-means++, AQE)"
echo ""
echo "Đường dẫn HDFS:"
echo "  Đầu vào: $HDFS_INPUT"
echo "  Đầu ra: $HDFS_OUTPUT"
echo ""

# Dọn dẹp kết quả cũ trong HDFS
echo "Đang dọn dẹp kết quả cũ..."
hdfs dfs -rm -r -f "$HDFS_BASE/output_centroids" 2>/dev/null

# Chạy K-means với MLlib
# Mặc định
MAX_ITER=15
K=5
SEED=42
TOL=0.0001

# Parse named arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --k)
            K="$2"
            shift 2
            ;;
        --max-iter)
            MAX_ITER="$2"
            shift 2
            ;;
        --seed)
            SEED="$2"
            shift 2
            ;;
        --tol)
            TOL="$2"
            shift 2
            ;;
        *)
            # Fallback: positional args for backward compatibility
            # $1=K, $2=MAX_ITER, $3=SEED, $4=TOL
            if [ -n "${1:-}" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                K="$1"
                [ -n "${2:-}" ] && MAX_ITER="$2"
                [ -n "${3:-}" ] && SEED="$3"
                [ -n "${4:-}" ] && TOL="$4"
            fi
            break
            ;;
    esac
done

echo "Đang chạy K-means với Spark MLlib..."
echo "Số cụm: $K"
echo "Số lần lặp tối đa: $MAX_ITER"
echo "Seed: $SEED"
echo "Tol: $TOL"
echo ""

# Chạy với YARN (hoặc standalone/local-cluster để test)
# Thay đổi --master thành:
#   - yarn: cho YARN cluster
#   - spark://master:7077: cho Spark standalone
#   - local[*]: cho chế độ local với tất cả cores
#   - local-cluster[N,C,M]: N workers, C cores mỗi worker, M MB memory (Spark 4.x yêu cầu MB là số nguyên)

# Chuyển đổi memory sang MB cho local-cluster (ví dụ: 4g -> 4096)
EXECUTOR_MEMORY_MB=$(echo "$EXECUTOR_MEMORY" | sed 's/g$//' | awk '{print $1*1024}')

spark-submit \
    --master local-cluster[${EXECUTOR_INSTANCES},${EXECUTOR_CORES},${EXECUTOR_MEMORY_MB}] \
    --deploy-mode client \
    --driver-memory "$DRIVER_MEMORY" \
    --executor-memory "$EXECUTOR_MEMORY" \
    --executor-cores $EXECUTOR_CORES \
    --num-executors $EXECUTOR_INSTANCES \
    --conf spark.sql.shuffle.partitions=800 \
    --conf spark.default.parallelism=800 \
    --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
    --conf spark.kryoserializer.buffer.max=512m \
    --conf spark.driver.maxResultSize=2g \
    --conf spark.memory.offHeap.enabled=true \
    --conf spark.memory.offHeap.size=4g \
    --conf spark.sql.adaptive.enabled=true \
    --conf spark.sql.adaptive.coalescePartitions.enabled=true \
    --conf spark.hadoop.fs.defaultFS="$HDFS_URI" \
    "$SCRIPT_DIR/kmeans_spark.py" \
    "$HDFS_INPUT" \
    "$HDFS_OUTPUT" \
    "$K" \
    "$MAX_ITER" \
    "$SEED" \
    "$TOL"

if [ $? -ne 0 ]; then
    echo "PySpark job thất bại"
    exit 1
fi

echo ""
echo "K-means MLlib hoàn thành!"
echo "Tâm cụm đã lưu vào: $HDFS_OUTPUT"
echo ""
echo "Để xem kết quả:"
echo "  hdfs dfs -cat $HDFS_BASE/output_centroids/part-*"
