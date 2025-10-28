# Polars + PySpark Pipeline

Pipeline phân tích dữ liệu HI-Large_Trans.csv sử dụng Polars và Apache Spark (PySpark).

> 📚 Xem thêm: [HƯỚNG DẪN CHẠY](HUONG_DAN_CHAY.md) · [BÁO CÁO](BAO_CAO_TIEU_LUAN.md) · [HADOOP_ALTERNATIVES](docs/HADOOP_ALTERNATIVES.md)

## Mục lục
- [Nâng cấp từ Hadoop sang Spark](#nang-cap)
- [Cấu trúc thư mục](#cau-truc)
- [Cài đặt](#cai-dat)
- [Chuẩn bị dữ liệu](#chuan-bi-du-lieu)
- [HDFS-Only Workflow](#hdfs-workflow)
- [Chạy Pipeline](#chay-pipeline)
- [Dọn dẹp Project](#don-dep)
- [Dữ liệu trên HDFS](#du-lieu-hdfs)
- [Chi tiết Pipeline Steps](#chi-tiet-steps)
- [Kiến trúc hệ thống](#kien-truc)
- [So sánh Hadoop vs Spark](#so-sanh)
- [Lợi ích Apache Spark](#loi-ich)
- [So sánh với các phương pháp khác](#phuong-phap-khac)

<a id="nang-cap"></a>
## ⚡ Nâng cấp từ Hadoop sang Spark

Project đã được cập nhật để sử dụng **Apache Spark** thay vì Hadoop MapReduce, giúp:
- ⚡ **Xử lý nhanh hơn** nhiều lần (in-memory computing)
- 🔧 **Dễ cài đặt hơn** (không cần HDFS)
- 📝 **Code đơn giản hơn** (PySpark API)
- 🚀 **Scale tốt hơn** với big data

<a id="cau-truc"></a>
## Cấu trúc thư mục

```
Final/
├── data/
│   ├── raw/                    # CSV gốc (HI-Large_Trans.csv)
│   ├── processed/              # Temp files (tự động xóa sau upload HDFS)
│   └── results/                # Kết quả từ HDFS (tùy chọn tải về)
├── docs/
│   ├── HADOOP_ALTERNATIVES.md  # So sánh các phương pháp clustering
│   └── Polars_Hadoop_HI_Large.md  # Legacy Hadoop workflow
├── logs/                       # Pipeline execution logs
├── scripts/
│   ├── polars/                 # Data processing với Polars
│   │   ├── explore_fast.py
│   │   ├── prepare_polars.py
│   │   ├── init_centroids.py
│   │   ├── assign_clusters_polars.py
│   │   └── analyze_polars.py
│   ├── spark/                  # PySpark implementation
│   │   ├── setup_hdfs.sh
│   │   ├── run_spark.sh
│   │   ├── kmeans_spark.py
│   │   └── download_from_hdfs.sh
│   ├── pipeline/               # Pipeline orchestration
│   │   ├── full_pipeline_spark.sh
│   │   ├── clean_spark.sh
│   │   └── reset_pipeline.sh
│   └── setup/                  # Installation
│       └── install_spark.sh
├── archive/
│   └── hadoop/                 # Legacy MapReduce code
├── CHANGELOG.md
└── README.md
```

<a id="cai-dat"></a>
## Cài đặt

### Apache Spark

```bash
# Cài đặt Spark (CachyOS/Arch Linux)
./scripts/setup/install_spark.sh

# Reload shell để áp dụng biến môi trường
source ~/.zshrc

# Kiểm tra cài đặt
spark-submit --version
```

### Python Dependencies

```bash
# Kích hoạt virtual environment (nếu có)
source .venv/bin/activate

# Cài đặt packages
pip install polars numpy pyspark
```

<a id="chuan-bi-du-lieu"></a>
## Chuẩn bị dữ liệu

Đặt file CSV gốc vào thư mục raw:

```bash
cp /path/to/HI-Large_Trans.csv data/raw/
```

<a id="hdfs-workflow"></a>
## ⚠️ QUAN TRỌNG: HDFS-Only Workflow

Project này tuân thủ quy tắc **KHÔNG lưu dữ liệu lớn ở local**.

### Workflow:

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│ Raw CSV     │ ───> │ Temp Files   │ ───> │ HDFS        │
│ (data/raw/) │      │ (tạm thời)   │      │ (permanent) │
└─────────────┘      └──────────────┘      └─────────────┘
                            │                      │
                            │ (auto delete)        │
                            ▼                      ▼
                      [Xóa ngay sau            [Spark
                       khi upload]              processing]
```

### Cách thức hoạt động:

1. **Polars** đọc CSV gốc và tạo temp files trong `data/processed/`
2. **setup_hdfs.sh** upload files lên HDFS và **tự động xóa** temp files
3. **Spark** xử lý dữ liệu trực tiếp trên HDFS (distributed)
4. Kết quả được lưu trên HDFS tại `/user/spark/hi_large/`
5. *(Tùy chọn)* Tải kết quả nhỏ về `data/results/` để phân tích

### Lưu ý:

- ✅ Temp files tự động bị xóa sau khi upload HDFS
- ✅ Dữ liệu chính chỉ tồn tại trên HDFS
- ✅ Chỉ lưu kết quả phân tích nhỏ ở local (centroid, logs)
- ⚠️ Có thể sửa `HDFS_BASE` trong scripts nếu dùng cluster khác

<a id="chay-pipeline"></a>
## Chạy Pipeline

### Quick Start

```bash
# Chạy toàn bộ pipeline tự động
./scripts/pipeline/full_pipeline_spark.sh
```

Pipeline sẽ tự động:
1. Khám phá dữ liệu với Polars
2. Chuẩn bị features và normalize
3. Khởi tạo centroids
4. Upload lên HDFS (và xóa temp files)
5. Chạy K-means trên Spark
6. Tải kết quả và phân tích

### Manual Steps (nếu cần debug)

```bash
# 1. Khám phá dữ liệu
python scripts/polars/explore_fast.py

# 2. Chuẩn bị features (tạo temp files)
python scripts/polars/prepare_polars.py

# 3. Khởi tạo centroids (tạo temp files)
python scripts/polars/init_centroids.py

# 4. Upload lên HDFS và XÓA temp files
scripts/spark/setup_hdfs.sh

# 5. Chạy Spark K-means trên HDFS
scripts/spark/run_spark.sh

# 6. (Tùy chọn) Tải kết quả về
scripts/spark/download_from_hdfs.sh

# 7. Gán clusters
python scripts/polars/assign_clusters_polars.py

# 8. Phân tích kết quả
python scripts/polars/analyze_polars.py
```

### Logs

Logs được lưu tại `logs/pipeline_log_*.md` với timestamp.

<a id="don-dep"></a>
## Dọn dẹp Project

```bash
# Xóa tất cả temp files, logs, và checkpoints
./scripts/pipeline/clean_spark.sh

# Reset chỉ pipeline checkpoints (giữ lại data)
./scripts/pipeline/reset_pipeline.sh

# Sau khi clean, chạy lại pipeline
./scripts/pipeline/full_pipeline_spark.sh
```

<a id="du-lieu-hdfs"></a>
## Dữ liệu trên HDFS

### Cấu trúc HDFS:

```
/user/spark/hi_large/
├── input/
│   └── hadoop_input.txt      # Dữ liệu đã normalize (~33GB)
├── centroids.txt             # K centroids ban đầu
└── output_centroids/         # Final centroids từ Spark
    └── part-00000
```

### Kiểm tra dữ liệu:

```bash
# Xem cấu trúc
hdfs dfs -ls /user/spark/hi_large/

# Kiểm tra kích thước
hdfs dfs -du -h /user/spark/hi_large/

# Xem nội dung centroids
hdfs dfs -cat /user/spark/hi_large/output_centroids/part-00000
```

### Download kết quả (tùy chọn):

Kết quả nhỏ được tải về `data/results/` để phân tích local.

<a id="chi-tiet-steps"></a>
## Chi tiết Pipeline Steps

| Bước | Script | Mô tả | Thời gian |
|------|--------|-------|----------|
| 1 | `scripts/polars/explore_fast.py` | Khám phá dữ liệu nhanh | ~30s |
| 2 | `scripts/polars/prepare_polars.py` | Feature engineering & normalize | ~10 phút |
| 3 | `scripts/polars/init_centroids.py` | Khởi tạo K centroids | ~30s |
| 4 | `scripts/spark/setup_hdfs.sh` | Upload HDFS & xóa temp files | ~5 phút |
| 5 | `scripts/spark/run_spark.sh` | K-means trên Spark (HDFS) | ~15-30 phút |
| 6 | `scripts/spark/download_from_hdfs.sh` | Tải centroids từ HDFS | ~30s |
| 7 | `scripts/polars/assign_clusters_polars.py` | Gán clusters cho data | ~10 phút |
| 8 | `scripts/polars/analyze_polars.py` | Phân tích & báo cáo | ~2 phút |

**Tổng thời gian**: ~40-60 phút (tùy cluster configuration)

<a id="kien-truc"></a>
## Kiến trúc hệ thống

```
┌──────────────────────────────────────────────────────────────────┐
│                     HDFS-Only Workflow                           │
└──────────────────────────────────────────────────────────────────┘

    RAW CSV              POLARS              HDFS             SPARK
       │                   │                  │                │
   ┌───▼────┐         ┌───▼────┐        ┌───▼────┐       ┌───▼────┐
   │16GB CSV│────────>│ Temp   │───────>│ 33GB   │──────>│K-means │
   │data/raw│         │ Files  │ upload │Storage │ read  │Cluster │
   └────────┘         └────────┘        └────────┘       └────────┘
                           │                                   │
                           │ (auto delete)                     │
                           ▼                                   ▼
                      [Xóa ngay]                       [Results HDFS]
                                                              │
                                                              │
                                                              ▼
                                                      ┌────────────────┐
                                                      │  data/results/ │
                                                      │  (small files) │
                                                      └────────────────┘
```

### Đặc điểm:

- ✅ **KHÔNG lưu dữ liệu lớn local** - Temp files tự động xóa sau upload
- ✅ **Storage chỉ trên HDFS** - Tuân thủ quy định không lưu local  
- ✅ **Distributed processing** - Spark xử lý song song trên cluster
- ✅ **Scalable** - Thêm nodes để tăng performance
- ✅ **Fault-tolerant** - HDFS replication đảm bảo an toàn dữ liệu

<a id="so-sanh"></a>
## So sánh Hadoop vs Spark

| Tiêu chí | Hadoop MapReduce | Apache Spark (HDFS) |
|----------|------------------|---------------------|
| **Tốc độ** | Chậm (đọc/ghi disk) | Nhanh hơn 10-100x |
| **Storage** | HDFS | HDFS |
| **Processing** | Disk-based | In-memory |
| **Code** | Dài (mapper/reducer) | Ngắn gọn (PySpark API) |
| **Phù hợp** | Batch processing lớn | Iterative algorithms |

<a id="loi-ich"></a>
## Lợi ích Apache Spark

| Tiêu chí | Lợi ích |
|----------|--------|
| ⚡ **Tốc độ** | Nhanh hơn Hadoop 10-100x với K-means (in-memory) |
| 💾 **Memory** | In-memory processing giảm I/O disk |
| 🎯 **API** | PySpark DataFrame API đơn giản, dễ học |
| 🔧 **Debug** | Local mode không cần cluster để test |
| 📈 **Scale** | Horizontal scaling - thêm nodes dễ dàng |
| 🛡️ **Production** | Fault-tolerant, mature ecosystem |

<a id="phuong-phap-khac"></a>
### So sánh với các phương pháp khác:

Xem chi tiết tại: [`docs/HADOOP_ALTERNATIVES.md`](docs/HADOOP_ALTERNATIVES.md)
