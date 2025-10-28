# ⚡ Polars + Hadoop cho HI-Large_Trans.csv (Tối Ưu)

**File**: 16GB, 179M rows  
**Thời gian**: ~1.5 giờ (thay vì 3-5 giờ)

---

## Setup

```bash
pip install polars numpy scikit-learn
```

---

## Bước 1: Khám phá nhanh với Polars

```python
# explore_fast.py
import polars as pl

# Lazy scan - không load vào RAM
df = pl.scan_csv('HI-Large_Trans.csv')

# Xem schema
print(df.schema)

# Sample 100k rows
sample = df.head(100000).collect()
print(sample)
print(sample.describe())

# Check laundering distribution
print("\nLaundering distribution:")
print(df.select(pl.col('Is Laundering').value_counts()).collect())

# Check currencies
print("\nTop currencies:")
print(df.select(pl.col('Receiving Currency').value_counts().head(10)).collect())
```

**Chạy**: `python explore_fast.py`  
**Thời gian**: 10-20 giây

---

## Bước 2: Feature Engineering với Polars (FAST)

```python
# prepare_polars.py
import polars as pl
import numpy as np

print("Loading with Polars...")
df = pl.read_csv('HI-Large_Trans.csv')

print("Feature engineering...")
df_features = df.select([
    # Parse timestamp
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y-%m-%d %H:%M:%S').alias('datetime'),
    
    # Basic features
    pl.col('Amount Received').alias('amount_received'),
    pl.col('Amount Paid').alias('amount_paid'),
    
    # Derived features
    (pl.col('Amount Received') / (pl.col('Amount Paid') + 1e-6)).alias('amount_ratio'),
    
    # Time features
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y-%m-%d %H:%M:%S').dt.hour().alias('hour'),
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y-%m-%d %H:%M:%S').dt.weekday().alias('day_of_week'),
    
    # Route hash
    (pl.col('From Bank').hash() ^ pl.col('To Bank').hash()).alias('route_hash'),
    
    # Categorical
    pl.col('Receiving Currency').alias('recv_curr'),
    pl.col('Payment Currency').alias('payment_curr'),
    pl.col('Payment Format').alias('payment_format'),
])

print("Encoding categoricals...")
# Label encoding
df_features = df_features.with_columns([
    pl.col('recv_curr').cast(pl.Categorical).to_physical().alias('recv_curr_encoded'),
    pl.col('payment_curr').cast(pl.Categorical).to_physical().alias('payment_curr_encoded'),
    pl.col('payment_format').cast(pl.Categorical).to_physical().alias('payment_format_encoded'),
])

# Select numeric features
df_numeric = df_features.select([
    'amount_received',
    'amount_paid', 
    'amount_ratio',
    'hour',
    'day_of_week',
    'route_hash',
    'recv_curr_encoded',
    'payment_curr_encoded',
    'payment_format_encoded',
])

print("Normalizing...")
# Normalize (Polars style)
df_normalized = df_numeric.select([
    ((pl.col(c) - pl.col(c).mean()) / pl.col(c).std()).alias(c)
    for c in df_numeric.columns
])

print("Writing to hadoop_input.txt...")
df_normalized.write_csv('hadoop_input.txt', has_header=False)

print(f"✅ Created hadoop_input.txt with {len(df_normalized)} rows")
print(f"   Features: {df_normalized.columns}")
```

**Chạy**: `python prepare_polars.py`  
**Thời gian**: 10-15 phút (vs 30-60 phút với Pandas)

---

## Bước 3: Khởi tạo centroids

```python
# init_centroids.py
import numpy as np
import polars as pl

print("Sampling for centroid initialization...")
# Polars sampling
df = pl.read_csv('hadoop_input.txt', has_header=False, 
                 new_columns=[f'f{i}' for i in range(9)])

# Sample 100k rows
sample = df.sample(n=min(100000, len(df)))
data = sample.to_numpy()

k = 5  # Số clusters
print(f"Initializing {k} centroids from {len(data)} samples...")

indices = np.random.choice(len(data), k, replace=False)
centroids = data[indices]

np.savetxt('centroids.txt', centroids, delimiter=',', fmt='%.6f')
print(f"✅ Saved {k} centroids to centroids.txt")
```

**Chạy**: `python init_centroids.py`  
**Thời gian**: 30 giây

---

## Bước 4: MapReduce Scripts

### mapper.py
```python
#!/usr/bin/env python3
import sys
import numpy as np

# Load centroids
centroids = np.loadtxt('centroids.txt', delimiter=',')

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    
    try:
        point = np.array([float(x) for x in line.split(',')])
        
        # Find closest centroid
        distances = np.linalg.norm(centroids - point, axis=1)
        closest = np.argmin(distances)
        
        print(f"{closest}\t{line}")
    except:
        continue
```

### reducer.py
```python
#!/usr/bin/env python3
import sys
import numpy as np

current_cluster = None
sum_vector = None
count = 0

for line in sys.stdin:
    line = line.strip()
    try:
        cluster, point_str = line.split('\t')
    except:
        continue
    
    if current_cluster != cluster and current_cluster is not None:
        # Output new centroid
        new_centroid = sum_vector / count
        print(','.join(map(str, new_centroid)))
        sum_vector = None
        count = 0
    
    current_cluster = cluster
    point = np.array([float(x) for x in point_str.split(',')])
    
    if sum_vector is None:
        sum_vector = point
    else:
        sum_vector += point
    count += 1

# Last cluster
if count > 0:
    new_centroid = sum_vector / count
    print(','.join(map(str, new_centroid)))
```

```bash
chmod +x mapper.py reducer.py
```

---

## Bước 5: Chạy Hadoop (Optimized)

```bash
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
MAP_TASKS=$((CPU_CORES * 2))
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
  
  # Run MapReduce with optimizations
  hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -D mapred.map.tasks=$MAP_TASKS \
    -D mapred.reduce.tasks=$REDUCE_TASKS \
    -D mapreduce.input.fileinputformat.split.maxsize=134217728 \
    -D mapreduce.job.reduces=$REDUCE_TASKS \
    -files mapper.py,reducer.py,centroids.txt \
    -mapper "python3 mapper.py" \
    -reducer "python3 reducer.py" \
    -input /user/hadoop/hi_large/input/hadoop_input.txt \
    -output /user/hadoop/hi_large/output_iter_$i
  
  if [ $? -ne 0 ]; then
    echo "❌ MapReduce failed at iteration $i"
    exit 1
  fi
  
  # Download new centroids
  hdfs dfs -get /user/hadoop/hi_large/output_iter_$i/part-00000 centroids_new.txt
  
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
```

**Chạy**: `bash run_hadoop_optimized.sh`  
**Thời gian**: 45-60 phút

---

## Bước 6: Gán clusters với Polars (FAST)

```python
# assign_clusters_polars.py
import polars as pl
import numpy as np

print("Loading centroids...")
centroids = np.loadtxt('final_centroids.txt', delimiter=',')

print("Loading data...")
df = pl.read_csv('hadoop_input.txt', has_header=False,
                 new_columns=[f'f{i}' for i in range(9)])

print("Computing distances and assigning clusters...")
data = df.to_numpy()

# Vectorized distance calculation (FAST)
distances = np.sqrt(((data[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2))
clusters = np.argmin(distances, axis=1)

print("Saving results...")
np.savetxt('clustered_results.txt', clusters, fmt='%d')

print(f"✅ Assigned {len(clusters)} transactions to clusters")
print(f"   Results saved to clustered_results.txt")
```

**Chạy**: `python assign_clusters_polars.py`  
**Thời gian**: 5-8 phút

---

## Bước 7: Phân tích với Polars

```python
# analyze_polars.py
import polars as pl
import numpy as np

print("Loading results...")
clusters = np.loadtxt('clustered_results.txt', dtype=int)
df_original = pl.read_csv('HI-Large_Trans.csv')

# Add cluster column
df_result = df_original.with_columns(pl.Series('cluster', clusters))

print("\n=== CLUSTER ANALYSIS ===\n")

# Overall statistics
print(f"Total transactions: {len(df_result):,}")
print(f"Number of clusters: {df_result['cluster'].n_unique()}")

# Cluster distribution
print("\n--- Cluster Sizes ---")
cluster_counts = df_result.group_by('cluster').agg(
    pl.count().alias('count')
).sort('cluster')
print(cluster_counts)

# Laundering analysis
print("\n--- Laundering Rate per Cluster ---")
laundering_stats = df_result.group_by('cluster').agg([
    pl.count().alias('total'),
    pl.col('Is Laundering').sum().alias('laundering_count'),
    (pl.col('Is Laundering').sum() / pl.count() * 100).alias('laundering_rate')
]).sort('cluster')

print(laundering_stats)

# Identify high-risk clusters
high_risk = laundering_stats.filter(pl.col('laundering_rate') > 10.0)
print(f"\n⚠️  HIGH RISK CLUSTERS (>10% laundering):")
print(high_risk)

# Feature analysis per cluster
print("\n--- Feature Averages per Cluster ---")
feature_stats = df_result.group_by('cluster').agg([
    pl.col('Amount Received').mean().alias('avg_amount_received'),
    pl.col('Amount Paid').mean().alias('avg_amount_paid'),
    (pl.col('Amount Received') / pl.col('Amount Paid')).mean().alias('avg_ratio'),
]).sort('cluster')
print(feature_stats)

# Export suspicious transactions
if len(high_risk) > 0:
    high_risk_ids = high_risk['cluster'].to_list()
    print(f"\n📤 Exporting suspicious transactions from clusters: {high_risk_ids}")
    
    suspicious = df_result.filter(pl.col('cluster').is_in(high_risk_ids))
    suspicious.write_csv('suspicious_transactions.csv')
    print(f"   ✅ Saved {len(suspicious):,} suspicious transactions")

print("\n✅ Analysis complete!")
```

**Chạy**: `python analyze_polars.py`  
**Thời gian**: 2-3 phút

---

## Tổng Hợp Pipeline

```bash
# full_pipeline.sh
#!/bin/bash

echo "=== POLARS + HADOOP PIPELINE ==="
echo ""

# Step 1
echo "Step 1: Explore data"
python explore_fast.py
echo ""

# Step 2
echo "Step 2: Prepare features with Polars (10-15 min)"
python prepare_polars.py
echo ""

# Step 3
echo "Step 3: Initialize centroids"
python init_centroids.py
echo ""

# Step 4
echo "Step 4: Run Hadoop MapReduce (45-60 min)"
bash run_hadoop_optimized.sh
echo ""

# Step 5
echo "Step 5: Assign clusters with Polars (5-8 min)"
python assign_clusters_polars.py
echo ""

# Step 6
echo "Step 6: Analyze results"
python analyze_polars.py
echo ""

echo "=== DONE! Total time: ~1.5 hours ==="
```

**Chạy toàn bộ**: `bash full_pipeline.sh`

---

## Thời gian ước tính

| Bước | Thời gian | Tool |
|------|-----------|------|
| 1. Explore | 20 giây | Polars |
| 2. Prepare | 10-15 phút | Polars ⚡ |
| 3. Init centroids | 30 giây | Polars |
| 4. Hadoop MapReduce | 45-60 phút | Hadoop |
| 5. Assign clusters | 5-8 phút | Polars ⚡ |
| 6. Analyze | 2-3 phút | Polars ⚡ |
| **TOTAL** | **~1.5 giờ** | vs 3-5 giờ |

---

## Lợi ích Polars

✅ **Nhanh hơn 5-10x** so với Pandas  
✅ **Ít RAM hơn** (streaming-friendly)  
✅ **Lazy evaluation** (chỉ xử lý khi cần)  
✅ **Parallel by default**  
✅ **Syntax đơn giản**

---

## Troubleshooting

### Memory issues
```python
# Dùng lazy mode
df = pl.scan_csv('HI-Large_Trans.csv')
df.select([...]).sink_csv('output.txt')  # Stream to disk
```

### Hadoop không tìm thấy file
```bash
hdfs dfs -ls /user/hadoop/hi_large/
```

### Slow encoding
```python
# Giảm số categories
df = df.with_columns(
    pl.col('Receiving Currency').fill_null('Unknown')
)
```

---

## Output mong đợi

```
Cluster 0: 45M trans, 2.1% laundering   → NORMAL
Cluster 1: 28M trans, 16.8% laundering  → HIGH RISK ⚠️
Cluster 2: 38M trans, 3.2% laundering   → NORMAL
Cluster 3: 50M trans, 1.9% laundering   → NORMAL
Cluster 4: 18M trans, 11.5% laundering  → SUSPICIOUS ⚠️

Exported 46M suspicious transactions to suspicious_transactions.csv
```

---

## Files tạo ra

- `hadoop_input.txt` (~3-4GB normalized features)
- `centroids.txt` (K centroids)
- `final_centroids.txt` (converged centroids)
- `clustered_results.txt` (cluster labels cho mỗi row)
- `suspicious_transactions.csv` (high-risk transactions)
