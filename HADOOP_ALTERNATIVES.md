# 🚀 Giải Pháp Thay Thế Hadoop Cho Bước 4 (K-means Clustering)

## 📊 Tổng Quan

Bước 4 hiện tại sử dụng Hadoop MapReduce để chạy K-means clustering trên 180M rows (~33GB hadoop_input.txt). Đây là bottleneck lớn nhất trong pipeline.

**Vấn đề với Hadoop:**
- Overhead cao từ HDFS I/O (upload/download qua network)
- Serialize/deserialize dữ liệu mỗi iteration
- Shuffle phase chậm giữa mapper và reducer
- Không tận dụng tối đa RAM của single machine
- Thời gian xử lý: **1-2 giờ** cho 15 iterations

---

## 🔥 Giải Pháp 1: MiniBatch K-Means (Scikit-learn)

**Nhanh nhất và đơn giản nhất - KHUYẾN NGHỊ cho hầu hết trường hợp**

### Tại sao nhanh hơn?
- Chỉ load một phần dữ liệu vào RAM mỗi lần (streaming)
- Tận dụng optimized C/Cython code
- Không có network overhead
- Converge nhanh hơn (~5-8 iterations thay vì 15)

### Implementation

```python path=null start=null
# step4_minibatch_kmeans.py
import polars as pl
import numpy as np
from sklearn.cluster import MiniBatchKMeans
from time import time

print("Step 4: MiniBatch K-Means (Scikit-learn)")
start_time = time()

# Load dữ liệu đã chuẩn bị
print("Loading data...")
df = pl.read_csv('hadoop_input.txt', has_header=False, 
                 new_columns=['Amount_Received', 'Amount_Paid', 'amount_ratio', 'hour'])

# Chuyển sang numpy array
X = df.to_numpy()
print(f"Data shape: {X.shape}")

# MiniBatch K-Means
print("\nTraining MiniBatch K-Means...")
kmeans = MiniBatchKMeans(
    n_clusters=5,
    batch_size=100000,      # Process 100K rows at a time
    max_iter=100,           # Max iterations
    random_state=42,
    verbose=1,
    compute_labels=False,   # Chỉ train centroids, không assign labels
    init='k-means++',
    n_init=3                # Số lần khởi tạo
)

# Có thể train trên chunks nếu RAM không đủ
# Uncomment block này nếu RAM < 16GB:
# chunk_size = 10_000_000
# for i in range(0, len(X), chunk_size):
#     print(f"Processing chunk {i//chunk_size + 1}...")
#     kmeans.partial_fit(X[i:i+chunk_size])

# Train toàn bộ (nếu RAM đủ)
kmeans.fit(X)

# Lưu centroids
centroids = kmeans.cluster_centers_
np.savetxt('final_centroids.txt', centroids, delimiter='\t', fmt='%.6f')

elapsed_time = time() - start_time
print(f"\n✅ Completed in {elapsed_time/60:.2f} minutes")
print(f"Centroids saved to final_centroids.txt")
print(f"Inertia: {kmeans.inertia_:.2f}")
```

### Kết quả dự kiến
- **Thời gian**: 8-15 phút (thay vì 1-2 giờ)
- **Tốc độ tăng**: 8-12x nhanh hơn
- **RAM cần**: 8-16GB
- **Accuracy**: ~95-98% so với standard K-Means

### Chạy pipeline mới

```bash
# Sửa file full_pipeline.sh, thay dòng 132:
# bash run_hadoop_optimized.sh 2>&1 | tee -a "$LOG_FILE"
# Thành:
python step4_minibatch_kmeans.py 2>&1 | tee -a "$LOG_FILE"
```

---

## ⚡ Giải Pháp 2: Dask-ML K-Means (Parallel + Out-of-Core)

**Tốt nhất khi có nhiều CPU cores và muốn 100% accuracy**

### Tại sao nhanh hơn?
- Parallel processing trên tất cả CPU cores
- Out-of-core: xử lý dữ liệu lớn hơn RAM
- Thuật toán giống sklearn nhưng distributed

### Implementation

```python path=null start=null
# step4_dask_kmeans.py
import dask.dataframe as dd
import dask.array as da
from dask_ml.cluster import KMeans
from time import time
import numpy as np

print("Step 4: Dask-ML K-Means (Parallel)")
start_time = time()

# Load với Dask (lazy)
print("Loading data with Dask...")
df = dd.read_csv('hadoop_input.txt', header=None, 
                 names=['Amount_Received', 'Amount_Paid', 'amount_ratio', 'hour'],
                 blocksize='256MB')  # Process in 256MB chunks

# Convert to dask array
X = df.to_dask_array(lengths=True)
print(f"Data shape: {X.shape}")

# Dask K-Means
print("\nTraining Dask K-Means...")
kmeans = KMeans(
    n_clusters=5,
    init='k-means++',
    max_iter=100,
    random_state=42
)

kmeans.fit(X)

# Lưu centroids
centroids = kmeans.cluster_centers_
np.savetxt('final_centroids.txt', centroids, delimiter='\t', fmt='%.6f')

elapsed_time = time() - start_time
print(f"\n✅ Completed in {elapsed_time/60:.2f} minutes")
print(f"Centroids saved to final_centroids.txt")
```

### Cài đặt

```bash
pip install dask[complete] dask-ml
```

### Kết quả dự kiến
- **Thời gian**: 15-25 phút
- **Tốc độ tăng**: 4-6x nhanh hơn
- **RAM cần**: Có thể xử lý data > RAM
- **Accuracy**: 100% giống standard K-Means

---

## 🔬 Giải Pháp 3: FAISS K-Means (GPU-accelerated)

**Nhanh nhất nếu có GPU**

### Tại sao nhanh hơn?
- Chạy trên GPU (hàng nghìn cores)
- Optimized cho high-dimensional data
- Vector operations siêu nhanh

### Implementation

```python path=null start=null
# step4_faiss_kmeans.py
import polars as pl
import numpy as np
import faiss
from time import time

print("Step 4: FAISS K-Means (GPU-accelerated)")
start_time = time()

# Load data
print("Loading data...")
df = pl.read_csv('hadoop_input.txt', has_header=False,
                 new_columns=['Amount_Received', 'Amount_Paid', 'amount_ratio', 'hour'])
X = df.to_numpy().astype('float32')  # FAISS requires float32

print(f"Data shape: {X.shape}")
n_samples, n_features = X.shape

# FAISS K-Means
print("\nTraining FAISS K-Means...")
n_clusters = 5
kmeans = faiss.Kmeans(
    d=n_features,           # dimensionality
    k=n_clusters,           # number of clusters
    niter=100,              # max iterations
    verbose=True,
    gpu=True,               # Use GPU (set False if no GPU)
    nredo=3,                # số lần khởi tạo
    seed=42
)

# Train
kmeans.train(X)

# Lưu centroids
centroids = kmeans.centroids
np.savetxt('final_centroids.txt', centroids, delimiter='\t', fmt='%.6f')

elapsed_time = time() - start_time
print(f"\n✅ Completed in {elapsed_time/60:.2f} minutes")
print(f"Centroids saved to final_centroids.txt")
print(f"Final objective: {kmeans.obj[-1]:.2f}")
```

### Cài đặt

```bash
# CPU version
pip install faiss-cpu

# GPU version (nếu có CUDA)
pip install faiss-gpu
```

### Kết quả dự kiến
- **Thời gian GPU**: 3-5 phút (30-40x nhanh hơn!)
- **Thời gian CPU**: 10-15 phút (8-12x nhanh hơn)
- **RAM/VRAM cần**: 8-16GB
- **Accuracy**: 100%

---

## 🔥 Giải Pháp 4: Apache Spark MLlib

**Tốt nhất cho distributed computing với API dễ dùng hơn Hadoop**

### Tại sao tốt hơn Hadoop?
- API high-level dễ dùng hơn MapReduce
- In-memory processing (nhanh hơn 10-100x so với Hadoop)
- Không cần viết mapper/reducer thủ công
- MLlib có sẵn K-Means optimized
- Vẫn distributed như Hadoop nhưng hiện đại hơn

### Implementation

```python path=null start=null
# step4_spark_kmeans.py
from pyspark.sql import SparkSession
from pyspark.ml.clustering import KMeans
from pyspark.ml.feature import VectorAssembler
from time import time
import numpy as np

print("Step 4: Apache Spark K-Means")
start_time = time()

# Khởi tạo Spark
spark = SparkSession.builder \
    .appName("HI-Large K-Means") \
    .config("spark.driver.memory", "4g") \
    .config("spark.executor.memory", "4g") \
    .config("spark.sql.shuffle.partitions", "200") \
    .config("spark.default.parallelism", "200") \
    .getOrCreate()

print("Loading data...")
# Load dữ liệu
df = spark.read.csv('hadoop_input.txt', inferSchema=True, header=False)
df = df.toDF('Amount_Received', 'Amount_Paid', 'amount_ratio', 'hour')

print(f"Data loaded: {df.count()} rows")

# Vector assembly (Spark MLlib requires vector format)
assembler = VectorAssembler(
    inputCols=['Amount_Received', 'Amount_Paid', 'amount_ratio', 'hour'],
    outputCol='features'
)
df_features = assembler.transform(df)

# K-Means
print("\nTraining Spark K-Means...")
kmeans = KMeans(
    k=5,
    maxIter=100,
    seed=42,
    featuresCol='features',
    predictionCol='cluster'
)

# Train
model = kmeans.fit(df_features)

# Lấy centroids
centroids = model.clusterCenters()
centroids_array = np.array(centroids)

# Lưu centroids
np.savetxt('final_centroids.txt', centroids_array, delimiter='\t', fmt='%.6f')

# Metrics
wssse = model.summary.trainingCost
print(f"\nWithin Set Sum of Squared Errors: {wssse:.2f}")
print(f"Number of iterations: {model.summary.numIter}")

elapsed_time = time() - start_time
print(f"\n✅ Completed in {elapsed_time/60:.2f} minutes")
print(f"Centroids saved to final_centroids.txt")

# Cleanup
spark.stop()
```

### Cài đặt

```bash
# Cài PySpark
pip install pyspark

# Hoặc với conda
conda install pyspark
```

### Kết quả dự kiến
- **Thời gian (local mode)**: 20-30 phút
- **Thời gian (cluster mode)**: 10-15 phút
- **Tốc độ tăng**: 3-6x nhanh hơn Hadoop
- **RAM cần**: 8-16GB (local), scalable (cluster)
- **Accuracy**: 100%

### Spark vs Hadoop

| Tiêu chí | Hadoop MapReduce | Apache Spark |
|----------|------------------|-------------|
| Xử lý | Disk-based | In-memory |
| API | Low-level (mapper/reducer) | High-level (DataFrame, ML) |
| Tốc độ | Baseline | 10-100x nhanh hơn |
| Code | Nhiều, phức tạp | Ít, dễ hiểu |
| Iterative algorithms | Chậm (write to disk) | Nhanh (keep in memory) |
| Setup | Đơn giản | Medium |

### Spark Standalone (Local Mode)

```python path=null start=null
# step4_spark_kmeans_local.py - Simplified cho single machine
from pyspark.sql import SparkSession
from pyspark.ml.clustering import KMeans
from pyspark.ml.feature import VectorAssembler
import numpy as np

# Spark local mode - dùng tất cả cores
spark = SparkSession.builder \
    .appName("HI-Large K-Means Local") \
    .master("local[*]") \
    .config("spark.driver.memory", "8g") \
    .config("spark.driver.maxResultSize", "4g") \
    .getOrCreate()

print("Loading data with Spark (local mode)...")
df = spark.read.csv('hadoop_input.txt', inferSchema=True, header=False) \
    .toDF('f0', 'f1', 'f2', 'f3')

# Cache để tăng tốc
df.cache()
print(f"Total rows: {df.count():,}")

# Vector assembly
assembler = VectorAssembler(inputCols=['f0', 'f1', 'f2', 'f3'], outputCol='features')
df_vec = assembler.transform(df).select('features')

# K-Means với tuning
kmeans = KMeans(k=5, seed=42, maxIter=100, initMode='k-means||')
model = kmeans.fit(df_vec)

# Lưu kết quả
centroids = np.array(model.clusterCenters())
np.savetxt('final_centroids.txt', centroids, delimiter='\t', fmt='%.6f')

print(f"✅ WSSSE: {model.summary.trainingCost:.2f}")
print(f"Iterations: {model.summary.numIter}")

spark.stop()
```

### Chạy với Spark Submit (Production)

```bash
# submit_spark_job.sh
spark-submit \
  --master local[*] \
  --driver-memory 8g \
  --executor-memory 8g \
  --conf spark.sql.shuffle.partitions=200 \
  --conf spark.default.parallelism=200 \
  step4_spark_kmeans.py
```

### Ưu điểm Spark so với các giải pháp khác

✅ **vs Hadoop MapReduce**:
- Nhanh hơn 10-30x (in-memory)
- Code ngắn gọn hơn rất nhiều
- API hiện đại, dễ maintain

✅ **vs Scikit-learn/FAISS**:
- Scalable ra nhiều máy (horizontal scaling)
- Xử lý được data > RAM của 1 máy
- Fault tolerant (production-ready)

❌ **vs Scikit-learn MiniBatch**:
- Chậm hơn trên single machine
- Setup phức tạp hơn
- Overhead từ Spark framework

### Khi nào nên dùng Spark?

✅ **NÊN dùng khi**:
- Có cluster nhiều máy
- Dữ liệu > 100GB
- Cần fault tolerance cao
- Pipeline có nhiều bước ML khác
- Team đã quen với Spark ecosystem

❌ **KHÔNG NÊN dùng khi**:
- Single machine đủ RAM (dùng MiniBatch/FAISS nhanh hơn)
- Chỉ cần POC/prototype
- Dữ liệu < 50GB (overhead không đáng)

---

## 🐻 Giải Pháp 5: Polars + Custom K-Means

**Best balance giữa tốc độ và control**

### Implementation

```python path=null start=null
# step4_polars_kmeans.py
import polars as pl
import numpy as np
from time import time

def kmeans_iteration(df, centroids):
    """Một iteration của K-means using Polars"""
    # Tính khoảng cách đến tất cả centroids
    distances = []
    for i, centroid in enumerate(centroids):
        dist_expr = pl.lit(0.0)
        for j, col in enumerate(df.columns):
            dist_expr = dist_expr + (pl.col(col) - centroid[j]) ** 2
        distances.append(dist_expr.sqrt().alias(f'dist_{i}'))
    
    # Assign clusters
    df_with_dist = df.with_columns(distances)
    dist_cols = [f'dist_{i}' for i in range(len(centroids))]
    df_clustered = df_with_dist.with_columns(
        pl.concat_list(dist_cols).list.arg_min().alias('cluster')
    )
    
    # Tính centroids mới
    new_centroids = []
    for i in range(len(centroids)):
        cluster_data = df_clustered.filter(pl.col('cluster') == i)
        if len(cluster_data) > 0:
            centroid = cluster_data.select(df.columns).mean().to_numpy()[0]
            new_centroids.append(centroid)
        else:
            new_centroids.append(centroids[i])  # Keep old centroid
    
    return np.array(new_centroids), df_clustered['cluster']

print("Step 4: Custom K-Means with Polars")
start_time = time()

# Load data
print("Loading data...")
df = pl.read_csv('hadoop_input.txt', has_header=False,
                 new_columns=['f0', 'f1', 'f2', 'f3'])

# Load initial centroids
centroids = np.loadtxt('centroids.txt', delimiter='\t')
print(f"Data shape: {df.shape}")
print(f"Initial centroids shape: {centroids.shape}")

# K-Means iterations
max_iter = 100
tolerance = 1e-4

for iteration in range(max_iter):
    print(f"\nIteration {iteration + 1}/{max_iter}")
    
    # Một iteration
    new_centroids, labels = kmeans_iteration(df, centroids)
    
    # Check convergence
    centroid_shift = np.linalg.norm(new_centroids - centroids)
    print(f"Centroid shift: {centroid_shift:.6f}")
    
    if centroid_shift < tolerance:
        print(f"✅ Converged at iteration {iteration + 1}")
        break
    
    centroids = new_centroids

# Lưu centroids
np.savetxt('final_centroids.txt', centroids, delimiter='\t', fmt='%.6f')

elapsed_time = time() - start_time
print(f"\n✅ Completed in {elapsed_time/60:.2f} minutes")
```

### Kết quả dự kiến
- **Thời gian**: 20-30 phút
- **Tốc độ tăng**: 3-5x nhanh hơn
- **RAM cần**: 16-32GB
- **Accuracy**: 100%

---

## 📊 So Sánh Các Giải Pháp

| Phương Pháp | Thời Gian | Tốc Độ Tăng | RAM Cần | Accuracy | Độ Phức Tạp | Khuyến Nghị |
|-------------|-----------|-------------|---------|----------|-------------|-------------|
| **Hadoop MapReduce** (hiện tại) | 1-2 giờ | 1x | 4-8GB | 100% | Medium | ❌ Chậm nhất |
| **MiniBatch K-Means** | 8-15 phút | 8-12x | 8-16GB | 95-98% | Easy | ✅ **BEST** |
| **Dask-ML K-Means** | 15-25 phút | 4-6x | >RAM OK | 100% | Easy | ✅ RAM thấp |
| **FAISS (GPU)** | 3-5 phút | 30-40x | 8GB VRAM | 100% | Medium | ✅ Có GPU |
| **FAISS (CPU)** | 10-15 phút | 8-12x | 8-16GB | 100% | Medium | ✅ Nhanh |
| **Spark (local)** | 20-30 phút | 3-6x | 8-16GB | 100% | Medium | ✅ Modern |
| **Spark (cluster)** | 10-15 phút | 6-12x | Scalable | 100% | Medium | ✅ Production |
| **Polars Custom** | 20-30 phút | 3-5x | 16-32GB | 100% | Hard | ⚠️ Advanced |

---

## 🎯 Khuyến Nghị Cụ Thể

### Trường hợp 1: Development/Testing (ưu tiên tốc độ)
```bash
# Dùng MiniBatch K-Means
pip install scikit-learn
python step4_minibatch_kmeans.py
```
**Kết quả**: 8-15 phút, accuracy 95-98%

### Trường hợp 2: Production (ưu tiên accuracy)
```bash
# Dùng FAISS CPU
pip install faiss-cpu
python step4_faiss_kmeans.py
```
**Kết quả**: 10-15 phút, accuracy 100%

### Trường hợp 3: Có GPU
```bash
# Dùng FAISS GPU
pip install faiss-gpu
python step4_faiss_kmeans.py
```
**Kết quả**: 3-5 phút, accuracy 100%

### Trường hợp 4: RAM thấp (<8GB)
```bash
# Dùng Dask-ML (out-of-core)
pip install dask[complete] dask-ml
python step4_dask_kmeans.py
```
**Kết quả**: 15-25 phút, accuracy 100%

### Trường hợp 5: Muốn thay Hadoop bằng framework hiện đại hơn
```bash
# Dùng Apache Spark (API dễ hơn, nhanh hơn Hadoop)
pip install pyspark
python step4_spark_kmeans.py
```
**Kết quả**: 20-30 phút (local), 10-15 phút (cluster), accuracy 100%

---

## 🔧 Migration Guide

### Bước 1: Chọn giải pháp
Dựa vào bảng so sánh và khuyến nghị trên

### Bước 2: Tạo file mới
Tạo file script tương ứng (ví dụ: `step4_minibatch_kmeans.py`)

### Bước 3: Sửa pipeline
Sửa file `full_pipeline.sh`:

```bash
# Tìm dòng 132:
bash run_hadoop_optimized.sh 2>&1 | tee -a "$LOG_FILE"

# Thay thành (ví dụ với MiniBatch):
python step4_minibatch_kmeans.py 2>&1 | tee -a "$LOG_FILE"
```

### Bước 4: Test
```bash
# Reset pipeline
./reset_pipeline.sh

# Chạy lại
./full_pipeline.sh
```

### Bước 5: Verify kết quả
```bash
# So sánh centroids
cat final_centroids.txt

# Chạy bước 5-6 như bình thường
python assign_clusters_polars.py
python analyze_polars.py
```

---

## ⚠️ Lưu Ý Quan Trọng

### 1. Compatibility với pipeline hiện tại
- Tất cả các giải pháp đều output `final_centroids.txt` cùng format
- Bước 5 và 6 không cần thay đổi
- Chỉ cần thay thế bước 4

### 2. Trade-offs
- **MiniBatch**: Mất một chút accuracy (~2-5%) nhưng cực nhanh
- **Dask/FAISS**: 100% accuracy nhưng cần cài thêm dependencies
- **GPU**: Cần CUDA/NVIDIA GPU

### 3. Khi nào vẫn nên dùng Hadoop?
- Dữ liệu > 100GB và không fit vào RAM
- Có cluster nhiều máy
- Cần fault tolerance cao (production critical)

### 4. Optimization tips
- Giảm số features nếu có thể (step 2)
- Sample data cho testing
- Tune `batch_size` và `max_iter`

---

## 📈 Ước Tính Hiệu Suất

### Pipeline hiện tại
```
Step 1: 1 phút
Step 2: 10 phút  
Step 3: <1 phút
Step 4: 90 phút (HADOOP) ⏰
Step 5: 15 phút
Step 6: 5 phút
--------------------
TOTAL: ~122 phút (~2 giờ)
```

### Pipeline mới (với MiniBatch K-Means)
```
Step 1: 1 phút
Step 2: 10 phút  
Step 3: <1 phút
Step 4: 10 phút (MiniBatch) ⚡
Step 5: 15 phút
Step 6: 5 phút
--------------------
TOTAL: ~42 phút
```

**Tăng tốc tổng thể**: **~3x nhanh hơn** (2 giờ → 42 phút)

---

## 🚀 Quick Start Commands

```bash
# Giải pháp khuyến nghị (MiniBatch K-Means)
pip install scikit-learn

# Tạo file step4_minibatch_kmeans.py (copy code từ Giải pháp 1)

# Sửa full_pipeline.sh dòng 132
# Từ: bash run_hadoop_optimized.sh 2>&1 | tee -a "$LOG_FILE"
# Thành: python step4_minibatch_kmeans.py 2>&1 | tee -a "$LOG_FILE"

# Reset và chạy
./reset_pipeline.sh
./full_pipeline.sh
```

**Expected result**: Pipeline hoàn thành trong 40-50 phút thay vì 2 giờ! 🎉

---

## 📞 Troubleshooting

### RAM không đủ
```python
# Trong step4_minibatch_kmeans.py, uncomment phần train theo chunks:
chunk_size = 10_000_000
for i in range(0, len(X), chunk_size):
    kmeans.partial_fit(X[i:i+chunk_size])
```

### Accuracy không đủ cao
```python
# Tăng batch_size và số iterations
kmeans = MiniBatchKMeans(
    n_clusters=5,
    batch_size=200000,    # Tăng từ 100K
    max_iter=200,         # Tăng từ 100
    n_init=5              # Tăng số lần khởi tạo
)
```

### Muốn giữ 100% accuracy
→ Dùng FAISS hoặc Dask-ML thay vì MiniBatch

---

## 🎓 Kết Luận

**TL;DR**: Thay Hadoop bằng **MiniBatch K-Means** (scikit-learn) để:
- ⚡ Giảm thời gian từ 90 phút → 10 phút (9x nhanh hơn)
- 🎯 Pipeline tổng thể: 2 giờ → 40 phút (3x nhanh hơn)
- 💻 Đơn giản hơn, không cần HDFS
- 📊 Accuracy vẫn rất tốt (95-98%)

**Khi nào dùng các giải pháp khác**:
- Có GPU → **FAISS GPU** (3-5 phút)
- Cần 100% accuracy → **FAISS CPU** hoặc **Dask-ML**
- RAM thấp → **Dask-ML** (out-of-core)
- Muốn upgrade từ Hadoop → **Apache Spark** (API hiện đại, nhanh hơn 10-30x)
- Có cluster → **Spark cluster mode** (scalable, production-ready)

### 💡 Spark vs Other Solutions

**Apache Spark là lựa chọn tốt nếu**:
- ✅ Bạn đã có Hadoop cluster (dễ migrate)
- ✅ Team quen với distributed systems
- ✅ Dữ liệu sẽ tiếp tục tăng lên
- ✅ Cần pipeline ML phức tạp hơn trong tương lai

**MiniBatch/FAISS tốt hơn Spark nếu**:
- ✅ Single machine đủ mạnh (RAM ≥ 16GB)
- ✅ Ưu tiên tốc độ tối đa
- ✅ Không cần distributed
- ✅ Setup đơn giản
