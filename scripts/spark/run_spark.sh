#!/bin/bash
# run_spark.sh - Chạy thuật toán K-means với PySpark trên HDFS

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
HDFS_CENTROIDS="$HDFS_URI$HDFS_BASE/centroids.txt"
HDFS_OUTPUT="$HDFS_URI$HDFS_BASE/output_centroids"

# Kiểm tra HDFS có đang chạy không
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "❌ HDFS không thể truy cập. Vui lòng khởi động HDFS trước."
    echo "   Chạy: start-dfs.sh"
    exit 1
fi

# Kiểm tra file đầu vào có tồn tại trong HDFS không
if ! hdfs dfs -test -e "$HDFS_BASE/input/hadoop_input.txt" 2>/dev/null; then
    echo "❌ Không tìm thấy file đầu vào trong HDFS: $HDFS_BASE/input/hadoop_input.txt"
    echo "   Vui lòng chạy: ./scripts/spark/setup_hdfs.sh"
    exit 1
fi

if ! hdfs dfs -test -e "$HDFS_BASE/centroids.txt" 2>/dev/null; then
    echo "❌ Không tìm thấy file tâm cụm trong HDFS: $HDFS_BASE/centroids.txt"
    echo "   Vui lòng chạy: ./scripts/spark/setup_hdfs.sh"
    exit 1
fi

# Lấy số CPU cores để tối ưu hóa
CPU_CORES=$(nproc)
EXECUTOR_CORES=4
EXECUTOR_INSTANCES=4
DRIVER_MEMORY="4g"
EXECUTOR_MEMORY="4g"

echo "Cấu hình:"
echo "  CPU cores: $CPU_CORES"
echo "  Số executor: $EXECUTOR_INSTANCES"
echo "  Executor cores: $EXECUTOR_CORES"
echo "  Executor memory: $EXECUTOR_MEMORY"
echo "  Driver memory: $DRIVER_MEMORY"
echo ""
echo "Đường dẫn HDFS:"
echo "  Đầu vào: $HDFS_INPUT"
echo "  Tâm cụm: $HDFS_CENTROIDS"
echo "  Đầu ra: $HDFS_OUTPUT"
echo ""

# Dọn dẹp kết quả cũ trong HDFS
echo "Đang dọn dẹp kết quả cũ..."
hdfs dfs -rm -r -f "$HDFS_BASE/output_centroids" 2>/dev/null

# Chạy PySpark K-means
MAX_ITER=15

echo "Đang chạy PySpark K-means clustering trên HDFS..."
echo "Số lần lặp tối đa: $MAX_ITER"
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
    --conf spark.sql.shuffle.partitions=200 \
    --conf spark.default.parallelism=200 \
    --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
    --conf spark.kryoserializer.buffer.max=512m \
    --conf spark.driver.maxResultSize=2g \
    --conf spark.hadoop.fs.defaultFS="$HDFS_URI" \
    --conf spark.yarn.archive=hdfs:///user/spark/spark-libs.jar \
    "$SCRIPT_DIR/kmeans_spark.py" \
    "$HDFS_INPUT" \
    "$HDFS_CENTROIDS" \
    "$HDFS_OUTPUT" \
    "$MAX_ITER"

if [ $? -ne 0 ]; then
    echo "❌ PySpark job thất bại"
    exit 1
fi

echo ""
echo "✅ PySpark K-means hoàn thành!"
echo "Tâm cụm cuối cùng đã lưu vào HDFS: $HDFS_OUTPUT"
echo ""
echo "Để xem kết quả:"
echo "  hdfs dfs -cat $HDFS_BASE/output_centroids/part-*"
