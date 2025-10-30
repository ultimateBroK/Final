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

| Hạng mục                        | Sinh viên 1 | Sinh viên 2 | Ghi chú                         |
|-------------------------------------|-------------|-------------|------------------------------------|
| Khảo sát thuật toán K-means      | X           |             | Tài liệu, ví dụ minh họa       |
| Thiết kế quy trình, pipeline     |             | X           | **7 bước** (MLlib k-means++) |
| Tiền xử lý dữ liệu (Polars)  | X           |             | Chuẩn hóa, mã hóa             |
| Spark MLlib K-means và tối ưu     |             | X           | Cấu hình, theo dõi hội tụ     |
| Gán nhãn và phân tích           | X           | X           | Tổng hợp kết quả              |
| Viết báo cáo, trình bày       | X           | X           | Biên tập cuối                |

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

#### Tổng quan quy trình 7 bước

⚠️ **Lưu ý**: Pipeline đã tối ưu từ 8 bước xuống còn 7 bước. Bước khởi tạo centroids đã loại bỏ vì MLlib K-means tự động dùng k-means++.

```
BƯỚC 1        BƯỚC 2        BƯỚC 3
Khám phá  →   Xử lý    →   Upload
 (30s)        (10 phút)      (5 phút)

BƯỚC 4            BƯỚC 5        BƯỚC 6        BƯỚC 7
K-means (MLlib) →   Tải về   →   Gán nhãn  →   Phân tích
(10-25p k-means++)    (30s)       (10 phút)     (2 phút)

TỔNG THỜI GIAN: 35-50 phút (nhanh hơn 30-50%!)
```

