#!/bin/bash
# run_spark.sh - Run K-means clustering with PySpark on HDFS

echo "=== PySpark K-means with HDFS ==="

# Resolve directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Set SPARK_HOME to pip-installed Spark
export SPARK_HOME="$ROOT_DIR/.venv/lib/python3.12/site-packages/pyspark"
export PATH="$SPARK_HOME/bin:$PATH"

# HDFS Configuration
HDFS_URI="hdfs://localhost:9000"
HDFS_BASE="/user/spark/hi_large"
HDFS_INPUT="$HDFS_URI$HDFS_BASE/input/hadoop_input.txt"
HDFS_CENTROIDS="$HDFS_URI$HDFS_BASE/centroids.txt"
HDFS_OUTPUT="$HDFS_URI$HDFS_BASE/output_centroids"

# Check if HDFS is running
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "❌ HDFS is not accessible. Please start HDFS first."
    echo "   Run: start-dfs.sh"
    exit 1
fi

# Check if input files exist in HDFS
if ! hdfs dfs -test -e "$HDFS_BASE/input/hadoop_input.txt" 2>/dev/null; then
    echo "❌ Input file not found in HDFS: $HDFS_BASE/input/hadoop_input.txt"
    echo "   Please run: ./scripts/spark/setup_hdfs.sh"
    exit 1
fi

if ! hdfs dfs -test -e "$HDFS_BASE/centroids.txt" 2>/dev/null; then
    echo "❌ Centroids file not found in HDFS: $HDFS_BASE/centroids.txt"
    echo "   Please run: ./scripts/spark/setup_hdfs.sh"
    exit 1
fi

# Get CPU cores for tuning
CPU_CORES=$(nproc)
EXECUTOR_CORES=4
EXECUTOR_INSTANCES=4
DRIVER_MEMORY="4g"
EXECUTOR_MEMORY="4g"

echo "Configuration:"
echo "  CPU cores: $CPU_CORES"
echo "  Executor instances: $EXECUTOR_INSTANCES"
echo "  Executor cores: $EXECUTOR_CORES"
echo "  Executor memory: $EXECUTOR_MEMORY"
echo "  Driver memory: $DRIVER_MEMORY"
echo ""
echo "HDFS paths:"
echo "  Input: $HDFS_INPUT"
echo "  Centroids: $HDFS_CENTROIDS"
echo "  Output: $HDFS_OUTPUT"
echo ""

# Clean old output in HDFS
echo "Cleaning old output..."
hdfs dfs -rm -r -f "$HDFS_BASE/output_centroids" 2>/dev/null

# Run PySpark K-means
MAX_ITER=15

echo "Running PySpark K-means clustering on HDFS..."
echo "Max iterations: $MAX_ITER"
echo ""

# Run with YARN (or standalone/local-cluster for testing)
# Change --master to:
#   - yarn: for YARN cluster
#   - spark://master:7077: for Spark standalone
#   - local[*]: for local mode with all cores
#   - local-cluster[N,C,M]: N workers, C cores each, M MB memory (Spark 4.x requires MB as integer)

# Convert memory to MB for local-cluster (e.g., 4g -> 4096)
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
    echo "❌ PySpark job failed"
    exit 1
fi

echo ""
echo "✅ PySpark K-means completed!"
echo "Final centroids saved to HDFS: $HDFS_OUTPUT"
echo ""
echo "To view results:"
echo "  hdfs dfs -cat $HDFS_BASE/output_centroids/part-*"
