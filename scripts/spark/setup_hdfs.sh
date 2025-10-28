#!/bin/bash
# setup_hdfs.sh - Setup HDFS directories and upload data for Spark pipeline

echo "=== Setting up HDFS for PySpark K-means ==="

# Resolve directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"

# HDFS Configuration
HDFS_BASE="/user/spark/hi_large"

# Check if HDFS is running
if ! hdfs dfs -test -e / 2>/dev/null; then
    echo "❌ HDFS is not accessible. Please start HDFS first."
    echo ""
    echo "To start HDFS:"
    echo "  1. Format namenode (first time only): hdfs namenode -format"
    echo "  2. Start HDFS: start-dfs.sh"
    echo "  3. Check status: jps"
    exit 1
fi

echo "✅ HDFS is accessible"
echo ""

# Check if temp data files exist
INPUT_TEMP="$DATA_PROCESSED/hadoop_input_temp.txt"
CENTROIDS_TEMP="$DATA_PROCESSED/centroids_temp.txt"

if [ ! -f "$INPUT_TEMP" ]; then
    echo "❌ Temp input file not found: $INPUT_TEMP"
    echo "   Please run data preparation first:"
    echo "   cd $ROOT_DIR/scripts/polars && python prepare_polars.py"
    exit 1
fi

if [ ! -f "$CENTROIDS_TEMP" ]; then
    echo "❌ Temp centroids file not found: $CENTROIDS_TEMP"
    echo "   Please run centroid initialization first:"
    echo "   cd $ROOT_DIR/scripts/polars && python init_centroids.py"
    exit 1
fi

echo "✅ Temp data files found"
echo ""

# Create HDFS directories
echo "Creating HDFS directories..."
hdfs dfs -mkdir -p "$HDFS_BASE/input"
hdfs dfs -mkdir -p "$HDFS_BASE/output"

# Clean old data
echo "Cleaning old data in HDFS..."
hdfs dfs -rm -f "$HDFS_BASE/input/*" 2>/dev/null
hdfs dfs -rm -f "$HDFS_BASE/centroids.txt" 2>/dev/null
hdfs dfs -rm -r -f "$HDFS_BASE/output_centroids" 2>/dev/null

# Upload input data
echo ""
echo "Uploading input data to HDFS..."
echo "  Source: $INPUT_TEMP"
echo "  Destination: $HDFS_BASE/input/hadoop_input.txt"
hdfs dfs -put "$INPUT_TEMP" "$HDFS_BASE/input/hadoop_input.txt"

if [ $? -ne 0 ]; then
    echo "❌ Failed to upload input data"
    exit 1
fi

# Upload centroids
echo ""
echo "Uploading centroids to HDFS..."
echo "  Source: $CENTROIDS_TEMP"
echo "  Destination: $HDFS_BASE/centroids.txt"
hdfs dfs -put "$CENTROIDS_TEMP" "$HDFS_BASE/centroids.txt"

if [ $? -ne 0 ]; then
    echo "❌ Failed to upload centroids"
    exit 1
fi

# Delete temp files after successful upload (DON'T store data locally)
echo ""
echo "Cleaning up temp files..."
rm -f "$INPUT_TEMP" "$CENTROIDS_TEMP"
echo "✅ Temp files deleted (data now only on HDFS)"

# Verify uploads
echo ""
echo "Verifying uploads..."
INPUT_SIZE=$(hdfs dfs -du -h "$HDFS_BASE/input/hadoop_input.txt" | awk '{print $1 " " $2}')
CENTROIDS_SIZE=$(hdfs dfs -du -h "$HDFS_BASE/centroids.txt" | awk '{print $1 " " $2}')

echo "  ✅ Input data: $INPUT_SIZE"
echo "  ✅ Centroids: $CENTROIDS_SIZE"

# Show HDFS structure
echo ""
echo "HDFS directory structure:"
hdfs dfs -ls -R "$HDFS_BASE"

echo ""
echo "==================================="
echo "✅ HDFS setup completed successfully!"
echo "==================================="
echo ""
echo "HDFS paths:"
echo "  Input: hdfs://localhost:9000$HDFS_BASE/input/hadoop_input.txt"
echo "  Centroids: hdfs://localhost:9000$HDFS_BASE/centroids.txt"
echo "  Output: hdfs://localhost:9000$HDFS_BASE/output_centroids"
echo ""
echo "Next step: Run PySpark job"
echo "  ./scripts/spark/run_spark.sh"
