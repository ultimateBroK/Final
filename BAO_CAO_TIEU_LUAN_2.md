# BÁO CÁO TIỂU LUẬN: Phân cụm K-means

## MỤC LỤC

- [Bảng phân chia công việc](#bang-phan-chia-cong-viec)
- [I. Tổng quan và lý thuyết](#i-tong-quan-va-ly-thuyet)
  - [A. Giới thiệu về các thuật toán K-means](#a-gioi-thieu-ve-cac-thuat-toan-k-means)
    - [1. Thuật toán K-means](#1-thuat-toan-k-means)
      - [a. Cách thức hoạt động của K-means](#a-cach-thuc-hoat-dong-cua-k-means)
      - [b. K-means++](#b-k-means)
      - [c. Ưu điểm của K-means](#c-uu-diem-cua-k-means)
      - [d. Nhược điểm của K-means](#d-nhuoc-diem-cua-k-means)
      - [e. Các tham số quan trọng của K-means](#e-cac-tham-so-quan-trong-cua-k-means)
      - [f. Ứng dụng của K-means](#f-ung-dung-cua-k-means)
  - [B. Lý thuyết HDFS](#b-ly-thuyet-hdfs)
  - [C. Lý thuyết Apache Spark](#c-ly-thuyet-apache-spark)
  - [D. Các công nghệ sử dụng](#d-cac-cong-nghe-su-dung)
    - [Polars](#polars)
    - [PySpark](#pyspark)
    - [NumPy](#numpy)
    - [HDFS](#hdfs)
    - [Apache Spark](#apache-spark)
- [II. Mô tả bài toán](#ii-mo-ta-bai-toan)
  - [A. Lý do chọn đề tài](#a-ly-do-chon-de-tai)
  - [B. Mô tả bài toán](#b-mo-ta-bai-toan)
  - [C. Quy trình thực hiện](#c-quy-trinh-thuc-hien)

---

<a id="bang-phan-chia-cong-viec"></a>
## Bảng phân chia công việc

| Hạng mục | Sinh viên 1 | Sinh viên 2 | Ghi chú |
|---|---|---|---|
| Khảo sát thuật toán K-means | X |  | Tài liệu, ví dụ minh họa |
| Thiết kế quy trình, pipeline |  | X | 8 bước từ thô đến phân tích |
| Tiền xử lý dữ liệu (Polars) | X |  | Chuẩn hóa, mã hóa |
| Spark K-means và tối ưu |  | X | Cấu hình, theo dõi hội tụ |
| Gán nhãn và phân tích | X | X | Tổng hợp kết quả |
| Viết báo cáo, trình bày | X | X | Biên tập cuối |

---

<a id="i-tong-quan-va-ly-thuyet"></a>
## I. Tổng quan và lý thuyết

<a id="a-gioi-thieu-ve-cac-thuat-toan-k-means"></a>
### A. Giới thiệu về các thuật toán K-means

<a id="1-thuat-toan-k-means"></a>
#### 1. Thuật toán K-means

<a id="a-cach-thuc-hoat-dong-cua-k-means"></a>
##### a. Cách thức hoạt động của K-means

- Khởi tạo K tâm cụm (centroid) ban đầu.
- Lặp cho đến khi hội tụ:
  1) Gán mỗi điểm vào cụm có centroid gần nhất (thường dùng khoảng cách Euclidean).
  2) Cập nhật centroid bằng trung bình các điểm trong cụm.
- Dừng khi tâm cụm thay đổi rất nhỏ (dưới ngưỡng) hoặc đạt số vòng lặp tối đa.

<a id="b-k-means"></a>
##### b. K-means++

- Cách khởi tạo tâm cụm thông minh nhằm giảm rủi ro rơi vào nghiệm kém:
  - Chọn ngẫu nhiên 1 điểm làm tâm đầu tiên.
  - Với mỗi tâm tiếp theo, chọn xác suất tỉ lệ với bình phương khoảng cách đến tâm gần nhất.
- Lợi ích: thường hội tụ nhanh hơn và chất lượng phân cụm tốt hơn so với khởi tạo ngẫu nhiên.

<a id="c-uu-diem-cua-k-means"></a>
##### c. Ưu điểm của K-means

- Đơn giản, dễ cài đặt và giải thích.
- Tốc độ nhanh, mở rộng tốt cho dữ liệu lớn.
- Hiệu quả khi cụm có dạng lồi và phân tách khá rõ.

<a id="d-nhuoc-diem-cua-k-means"></a>
##### d. Nhược điểm của K-means

- Cần chọn trước K (số cụm).
- Nhạy cảm với tâm khởi tạo và outlier.
- Giả định cụm có phương sai gần nhau (hình cầu) và dùng cùng một thước đo khoảng cách.

<a id="e-cac-tham-so-quan-trong-cua-k-means"></a>
##### e. Các tham số quan trọng của K-means

- K (số cụm), init (random/K-means++), max_iter, n_init, tol (ngưỡng hội tụ), metric (thường là Euclidean).

<a id="f-ung-dung-cua-k-means"></a>
##### f. Ứng dụng của K-means

- Phân khúc khách hàng, gợi ý sản phẩm, phát hiện bất thường sơ bộ, nén dữ liệu (vector quantization), khởi tạo cho các thuật toán khác.

<a id="b-ly-thuyet-hdfs"></a>
### B. Lý thuyết HDFS

- HDFS (Hadoop Distributed File System) là hệ thống file phân tán, thiết kế để lưu trữ các file rất lớn trên cụm máy.
- Thành phần chính:
  - NameNode: Lưu metadata (namespace, vị trí block), điều phối truy cập.
  - DataNode: Lưu dữ liệu dạng block trên đĩa, phục vụ đọc/ghi.
- Khái niệm cốt lõi:
  - Block: Đơn vị lưu trữ (mặc định 128MB hoặc 256MB).
  - Replication Factor: Mỗi block được sao chép N bản để đảm bảo an toàn.
  - Rack Awareness: Phân phối bản sao trên nhiều rack để tăng tính sẵn sàng.
- Luồng ghi: Client yêu cầu NameNode → nhận danh sách DataNode → pipeline ghi theo chuỗi, từng block được replicate.
- Luồng đọc: Client hỏi NameNode vị trí block → đọc trực tiếp từ DataNode gần nhất (data locality).
- Ưu điểm: Dung lượng mở rộng tuyến tính, chịu lỗi tốt, throughput cao. Nhược: Độ trễ (latency) cao, không phù hợp file nhỏ rất nhiều.

Ví dụ lệnh HDFS thường dùng:

```bash
# Kiểm tra cụm HDFS
hdfs dfsadmin -report

# Tạo thư mục và upload
hdfs dfs -mkdir -p /user/spark/hi_large/input
hdfs dfs -put data/processed/hadoop_input_temp.txt /user/spark/hi_large/input/

# Liệt kê và kiểm tra kích thước
hdfs dfs -ls -h /user/spark/hi_large/input
hdfs dfs -du -h /user/spark/hi_large/input
```

<a id="c-ly-thuyet-apache-spark"></a>
### C. Lý thuyết Apache Spark

- Kiến trúc: Driver (điều phối) + Executors (thực thi) + Cluster Manager (Standalone/YARN/K8s).
- Mô hình thực thi: DAG của transformations → chia thành stages → tasks song song trên partitions.
- Khái niệm chính:
  - RDD/DataFrame/Dataset: Abstraction dữ liệu bất biến, phân tán.
  - Lazy Evaluation: Chỉ thực thi khi có action (count, collect, write...).
  - Catalyst Optimizer & Tungsten: Tối ưu logic và thực thi trong bộ nhớ.
  - Shuffle: Trao đổi dữ liệu giữa nodes theo key, chi phí cao cần hạn chế.
- Bộ nhớ: Phân vùng cho execution vs. storage; cache/persist để chia sẻ trung gian giữa các bước lặp.

Ví dụ K-means với PySpark MLlib (rút gọn):

```python
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.clustering import KMeans

spark = SparkSession.builder.getOrCreate()

# Đọc dữ liệu đã chuẩn hoá từ HDFS (ví dụ)
df = spark.read.csv(
    "hdfs:///user/spark/hi_large/input/hadoop_input.txt",
    header=False,
    inferSchema=True,
)

# Ghép cột đặc trưng thành vector cho MLlib
assembler = VectorAssembler(
    inputCols=[
        # điền danh sách cột đặc trưng số ở đây
    ],
    outputCol="features",
)
vec = assembler.transform(df).select("features").cache()

kmeans = KMeans(k=5, maxIter=15, seed=42, featuresCol="features", predictionCol="cluster")
model = kmeans.fit(vec)
centers = model.clusterCenters()
```

<a id="d-cac-cong-nghe-su-dung"></a>
### D. Các công nghệ sử dụng

<a id="polars"></a>
#### Polars

- Vai trò: Tiền xử lý nhanh trên 1 máy (CSV lớn), lazy/streaming vượt quá RAM.
- Tính năng: Expression API, parallel compute, memory efficient (Rust backend).
- Ví dụ:

```python
import polars as pl

df = pl.scan_csv("data/raw/HI-Large_Trans.csv")  # lazy, không tải hết vào RAM

features = (
    df.with_columns([
        (pl.col("Amount Received") / pl.col("Amount Paid")).alias("amount_ratio"),
    ])
    .select([
        pl.col("amount_ratio").clip(0, 10),
        pl.col("Payment Currency"),
    ])
)

features.sink_csv("data/processed/sample_features.csv")  # streaming
```

<a id="pyspark"></a>
#### PySpark

- Vai trò: API Python cho Spark; chạy phân tán, phù hợp thuật toán lặp như K-means.
- Tính năng: DataFrame, MLlib, Structured Streaming, Catalyst optimizer.
- Ví dụ lệnh submit:

```bash
spark-submit \
  --driver-memory 4g \
  --executor-memory 4g \
  scripts/spark/kmeans_spark.py
```

<a id="numpy"></a>
#### NumPy

- Vai trò: Tăng tốc tính toán vector/matrix, đặc biệt khi gán nhãn theo khoảng cách.
- Ví dụ tính khoảng cách Euclid theo batch:

```python
import numpy as np

X = np.random.rand(1_000_000, 9)  # features
C = np.random.rand(5, 9)          # centroids

dists = np.sqrt(((X[:, None, :] - C[None, :, :]) ** 2).sum(axis=2))
labels = dists.argmin(axis=1)
```

<a id="hdfs"></a>
#### HDFS

- Vai trò: Lưu trữ phân tán dữ liệu đã xử lý và kết quả mô hình; đảm bảo an toàn và mở rộng.
- Lệnh hữu ích: `hdfs dfs -put`, `-get`, `-ls -h`, `-du -h`, `dfsadmin -report`.

<a id="apache-spark"></a>
#### Apache Spark

- Vai trò: Nền tảng thực thi phân tán trong bộ nhớ; tối ưu cho xử lý lặp và ETL.
- Best practices: Cache dữ liệu dùng lại; tối ưu số partitions; giảm shuffle; giám sát UI tại `http://localhost:4040` khi chạy local.

---

<a id="ii-mo-ta-bai-toan"></a>
## II. Mô tả bài toán

<a id="a-ly-do-chon-de-tai"></a>
### A. Lý do chọn đề tài

- Dữ liệu giao dịch tài chính cực lớn, cần phân cụm để hiểu hành vi và nhận diện bất thường.
- K-means là thuật toán nhanh, dễ mở rộng, phù hợp cho bước phân nhóm nền tảng trước khi đi sâu.
- Tận dụng hạ tầng phân tán (Spark) và xử lý cục bộ nhanh (Polars) để rút ngắn thời gian.

<a id="b-mo-ta-bai-toan"></a>
### B. Mô tả bài toán

- Đầu vào: Tập dữ liệu giao dịch tài chính nhiều cột (thời gian, ngân hàng, tài khoản, số tiền, loại tiền...).
- Mục tiêu: Tiền xử lý và chuẩn hóa đặc trưng, sau đó phân cụm K-means để phân nhóm giao dịch có đặc điểm tương tự; dùng kết quả để phân tích cụm rủi ro.
- Ràng buộc: Tối ưu thời gian xử lý; không lưu dữ liệu lớn ở máy cục bộ sau khi đẩy lên HDFS.

<a id="c-quy-trinh-thuc-hien"></a>
### C. Quy trình thực hiện

#### Tổng quan quy trình 8 bước

```
BƯỚC 1        BƯỚC 2        BƯỚC 3        BƯỚC 4
Khám phá  →   Xử lý    →   Khởi tạo  →   Upload
 (30s)        (10 phút)      (30s)       (5 phút)

BƯỚC 5        BƯỚC 6        BƯỚC 7        BƯỚC 8
K-means   →   Tải về   →   Gán nhãn  →   Phân tích
(15-30p)       (30s)       (10 phút)     (2 phút)

TỔNG THỜI GIAN: 40-60 phút
```

#### Chi tiết từng bước

##### BƯỚC 1: Khám phá dữ liệu 🔍
**Mục đích**: Hiểu cấu trúc và đặc điểm của dữ liệu
**File thực thi**: `scripts/polars/explore_fast.py`
**Thời gian**: ~30 giây
**Input**: `data/raw/HI-Large_Trans.csv` (16GB)
**Output**: Thống kê in ra màn hình

**Các phân tích thực hiện**:
1. Đọc 100,000 dòng đầu (đại diện)
2. Xem schema: Tên cột, kiểu dữ liệu
3. Thống kê mô tả: min, max, mean, median, std
4. Phân tích nhãn: Bao nhiêu % rửa tiền?
5. Top loại tiền tệ phổ biến

**Kết quả ví dụ**:
```
Total rows: 179,702,229
Laundering rate: 0.126%
Top currencies: Euro (23%), Yuan (7.2%)
```

##### BƯỚC 2: Xử lý và trích xuất đặc trưng 🔧
**Mục đích**: Chuyển dữ liệu thô thành dạng số để thuật toán xử lý
**File thực thi**: `scripts/polars/prepare_polars.py`
**Thời gian**: ~10 phút
**Input**: `data/raw/HI-Large_Trans.csv` (16GB)
**Output**: `data/processed/hadoop_input_temp.txt` (33GB, TẠM THỜI)

**Các bước xử lý**:
1. **Parse timestamp**: "2022/08/01 00:17" → giờ=0, ngày=0 (Thứ 2)
2. **Tính ratio**: amount_ratio = 6794.63 / 7739.29 = 0.878
3. **Hash route**: hash(20, 20) = 400 (ví dụ)
4. **Encode currency**: "US Dollar" → 0, "Yuan" → 1
5. **Normalize**: Đưa tất cả về [0, 1]

**Tại sao lại tăng từ 16GB lên 33GB?**
- Dữ liệu gốc: Chỉ có 11 cột
- Sau xử lý: Thêm nhiều cột đặc trưng
- Mỗi số float64 = 8 bytes
- 179M rows × 9 features × 8 bytes ≈ 12GB + overhead ≈ 33GB

##### BƯỚC 3: Khởi tạo tâm cụm 🎯
**Mục đích**: Chọn điểm bắt đầu cho thuật toán K-means
**File thực thi**: `scripts/polars/init_centroids.py`
**Thời gian**: ~30 giây
**Input**: `data/processed/hadoop_input_temp.txt`
**Output**: `data/processed/centroids_temp.txt` (440 bytes)

**Thuật toán**:
1. Sample ngẫu nhiên 100,000 dòng
2. Chọn ngẫu nhiên K=5 dòng làm tâm cụm
3. Lưu 5 dòng này vào file

**Ví dụ tâm cụm**:
```
Cluster 0: [0.12, 0.34, 0.56, 0.78, 0.90, 0.11, 0.33, 0.55, 0.77]
Cluster 1: [0.88, 0.22, 0.44, 0.66, 0.11, 0.99, 0.22, 0.44, 0.66]
...
```

##### BƯỚC 4: Upload lên HDFS ☁️
**Mục đích**: Chuyển dữ liệu lên hệ thống lưu trữ phân tán
**File thực thi**: `scripts/spark/setup_hdfs.sh`
**Thời gian**: ~5 phút
**Input**: 2 file temp cục bộ
**Output**: Dữ liệu trên HDFS

**Các bước thực hiện**:
1. Kiểm tra HDFS đang chạy: `hdfs dfsadmin -report`
2. Tạo thư mục: `hdfs dfs -mkdir -p /user/spark/hi_large/input`
3. Upload input: `hdfs dfs -put hadoop_input_temp.txt /user/.../input/`
4. Upload centroids: `hdfs dfs -put centroids_temp.txt /user/.../`
5. **XÓA file temp cục bộ**: `rm -rf data/processed/*`
6. Verify: Kiểm tra kích thước file trên HDFS

**🔒 Tuân thủ quy định**:
- Sau bước này, KHÔNG còn dữ liệu lớn ở máy cục bộ
- Chỉ tồn tại trên HDFS (phân tán, an toàn)
- Nếu cần, có thể tải lại từ HDFS

##### BƯỚC 5: Chạy K-means trên Spark 🚀
**Mục đích**: Phân cụm 179 triệu giao dịch
**File thực thi**: `scripts/spark/run_spark.sh` + `kmeans_spark.py`
**Thời gian**: 15-30 phút (tùy phần cứng)
**Input**: Dữ liệu từ HDFS
**Output**: Tâm cụm cuối cùng trên HDFS

**Thuật toán K-means**:
```
KHỞ TẠO:
  - K=5 tâm cụm ban đầu (từ bước 3)
  - Max iterations = 15

LẶP LẠI 15 LẦN:
  1. Gán mỗi giao dịch vào cụm gần nhất
     - Tính khoảng cách Euclidean đến 5 tâm cụm
     - Chọn cụm có khoảng cách nhỏ nhất
  
  2. Cập nhật tâm cụm
     - Tính trung bình tất cả điểm trong mỗi cụm
     - Tâm cụm mới = trung bình các điểm
  
  3. Kiểm tra hội tụ
     - Tính độ dịch chuyển tâm cụm
     - Nếu < threshold → Dừng lại

KẾT QUẢ:
  - 5 tâm cụm cuối cùng
  - Mỗi cụm chứa bao nhiêu điểm
```

**Quá trình hội tụ (từ log thực tế)**:
```
Iteration  1: Centroid shift = 2.232  (chưa ổn định)
Iteration  2: Centroid shift = 1.409
Iteration  5: Centroid shift = 0.383
Iteration 10: Centroid shift = 0.046
Iteration 15: Centroid shift = 0.010  (đã hội tụ ✓)
```

**Phân phối kết quả**:
```
Cluster 0:  40,034,828 giao dịch (22.28%)
Cluster 1:  42,665,741 giao dịch (23.74%)
Cluster 2:  24,884,738 giao dịch (13.85%)
Cluster 3:  50,933,660 giao dịch (28.34%)  ← Lớn nhất
Cluster 4:  21,183,262 giao dịch (11.79%)
```

##### BƯỚC 6: Tải kết quả về 📥
**Mục đích**: Lấy tâm cụm cuối cùng từ HDFS
**File thực thi**: `scripts/spark/download_from_hdfs.sh`
**Thời gian**: ~30 giây
**Input**: `/user/spark/hi_large/output_centroids/` trên HDFS
**Output**: `data/results/final_centroids.txt` (~4KB)

**Các bước**:
1. `hdfs dfs -cat /user/.../output_centroids/part-*`
2. Lưu vào file cục bộ
3. Verify: Kiểm tra có đúng 5 dòng

**Tại sao được phép tải về?**
- File rất nhỏ (~4KB)
- Chỉ chứa kết quả tổng hợp, không phải dữ liệu gốc
- Cần thiết cho bước phân tích tiếp theo

##### BƯỚC 7: Gán nhãn cụm cho từng giao dịch 🏷️
**Mục đích**: Xác định mỗi giao dịch thuộc cụm nào
**File thực thi**: `scripts/polars/assign_clusters_polars.py`
**Thời gian**: ~10 phút
**Input**: 
  - CSV gốc từ HDFS (streaming)
  - 5 tâm cụm từ bước 6
**Output**: `data/results/clustered_results.txt`

**Thuật toán**:
```python
FOR mỗi giao dịch:
    distances = []
    FOR mỗi tâm cụm (5 cụm):
        d = euclidean_distance(giao_dịch, tâm_cụm)
        distances.append(d)
    
    cluster_id = argmin(distances)  # Chọn cụm gần nhất
    ghi_kết_quả(giao_dịch, cluster_id)
```

**Xử lý batch để tăng tốc**:
- Không xử lý từng giao dịch
- Xử lý 1 triệu giao dịch cùng lúc
- Sử dụng NumPy vectorization

##### BƯỚC 8: Phân tích kết quả 📊
**Mục đích**: Tìm cụm có tỷ lệ rửa tiền cao
**File thực thi**: `scripts/polars/analyze_polars.py`
**Thời gian**: ~2 phút
**Input**: `data/results/clustered_results.txt`
**Output**: Báo cáo phân tích

**Các phân tích thực hiện**:
1. **Kích thước cụm**: Mỗi cụm có bao nhiêu giao dịch?
2. **Tỷ lệ rửa tiền**: % rửa tiền trong từng cụm
3. **High-risk clusters**: Cụm nào > 10% rửa tiền?
4. **Feature averages**: Đặc điểm trung bình mỗi cụm

**Kết quả từ log thực tế**:
```
╔══════════╦═════════════╦═══════════╦═════════════════╗
║ Cluster  ║ Giao dịch   ║ Rửa tiền  ║ Tỷ lệ (%)       ║
╠══════════╬═════════════╬═══════════╬═════════════════╣
║    0     ║ 40,034,832  ║  52,327   ║ 0.13%           ║
║    1     ║ 42,665,746  ║  70,450   ║ 0.17% ← CAO     ║
║    2     ║ 24,884,738  ║  16,686   ║ 0.07%           ║
║    3     ║ 50,933,651  ║  82,943   ║ 0.16%           ║
║    4     ║ 21,183,262  ║   3,140   ║ 0.01% ← THẤP    ║
╚══════════╩═════════════╩═══════════╩═════════════════╝

💡 NHẬN XÉT:
- Cluster 1 nghi ngờ nhất (0.17%, cao hơn trung bình)
- Cluster 4 an toàn nhất (0.01%, thấp hơn nhiều)
- KHÔNG có cụm nào > 10% (good sign)
```

---


