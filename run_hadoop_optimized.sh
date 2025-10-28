#!/bin/bash
# run_hadoop_optimized.sh

echo "=== Polars + Hadoop Pipeline for HI-Large_Trans.csv ==="

# Upload to HDFS
echo "Uploading to HDFS..."
hdfs dfs -mkdir -p /user/hadoop/hi_large/input
hdfs dfs -put -f hadoop_input.txt /user/hadoop/hi_large/input/
hdfs dfs -put -f centroids.txt /user/hadoop/hi_large/

# Get CPU cores for tuning
CPU_CORES=$(nproc)
MAP_TASKS=$((CPU_CORES * 3))
REDUCE_TASKS=$((CPU_CORES))

echo "CPU cores: $CPU_CORES"
echo "Map tasks: $MAP_TASKS"
echo "Reduce tasks: $REDUCE_TASKS"

# Iterations
MAX_ITER=15

for i in $(seq 1 $MAX_ITER); do
  echo ""
  echo "=== Iteration $i/$MAX_ITER ==="
  
  # Clean old output
  hdfs dfs -rm -r -f /user/hadoop/hi_large/output_iter_$i
  
  # Run MapReduce with optimizations and memory settings
  hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -D mapreduce.job.maps=$MAP_TASKS \
    -D mapreduce.job.reduces=$REDUCE_TASKS \
    -D mapreduce.input.fileinputformat.split.maxsize=67108864 \
    -D mapreduce.map.memory.mb=2048 \
    -D mapreduce.map.java.opts=-Xmx1638m \
    -D mapreduce.reduce.memory.mb=4096 \
    -D mapreduce.reduce.java.opts=-Xmx3276m \
    -D mapreduce.reduce.shuffle.parallelcopies=20 \
    -D mapreduce.reduce.shuffle.input.buffer.percent=0.5 \
    -D mapreduce.reduce.shuffle.merge.percent=0.66 \
    -D mapreduce.task.io.sort.mb=512 \
    -D mapreduce.task.io.sort.factor=100 \
    -D mapreduce.map.output.compress=true \
    -D mapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.SnappyCodec \
    -files mapper.py,reducer.py,centroids.txt \
    -mapper "python3 mapper.py" \
    -reducer "python3 reducer.py" \
    -input /user/hadoop/hi_large/input/hadoop_input.txt \
    -output /user/hadoop/hi_large/output_iter_$i
  
  if [ $? -ne 0 ]; then
    echo "❌ MapReduce failed at iteration $i"
    exit 1
  fi
  
  # Download new centroids (merge all part files)
  hdfs dfs -getmerge /user/hadoop/hi_large/output_iter_$i centroids_new.txt
  
  # Check convergence
  if [ $i -gt 1 ]; then
    diff centroids.txt centroids_new.txt > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ Converged at iteration $i!"
      mv centroids_new.txt final_centroids.txt
      break
    fi
  fi
  
  # Update centroids
  mv centroids_new.txt centroids.txt
  hdfs dfs -put -f centroids.txt /user/hadoop/hi_large/
done

# Save final centroids
if [ ! -f final_centroids.txt ]; then
  cp centroids.txt final_centroids.txt
fi

echo ""
echo "✅ Training complete! Final centroids in final_centroids.txt"
