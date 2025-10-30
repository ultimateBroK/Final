# 📊 Dự Án Phân Tích Rửa Tiền - K-means Clustering

Pipeline phân tích 179 triệu giao dịch sử dụng Polars và Apache Spark (PySpark).

> 📚 **Xem thêm:** [Báo cáo dự án](bao_cao_du_an.md) · [Hướng dẫn](docs/huong-dan.md) · [Cài đặt](docs/cai-dat.md) · [Jupyter](docs/jupyter.md)

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
├── data/                      # Dữ liệu
│   ├── raw/                      # CSV gốc (HI-Large_Trans.csv)
│   ├── processed/                # Temp (tự động xóa sau upload HDFS)
│   └── results/                  # Kết quả (tải về từ HDFS)
├── scripts/                   # Scripts
│   ├── polars/                   # Data processing
│   │   ├── explore_fast.py
│   │   ├── prepare_polars.py
│   │   ├── assign_clusters_polars.py
│   │   └── analyze.py
│   ├── spark/                    # PySpark MLlib K-means
│   │   ├── setup_hdfs.sh
│   │   ├── run_spark.sh
│   │   ├── kmeans_spark.py
│   │   └── download_from_hdfs.sh
│   ├── pipeline/                 # Orchestration
│   │   ├── full_pipeline_spark.sh
│   │   ├── clean_spark.sh
│   │   └── reset_pipeline.sh
│   ├── setup/                    # Installation
│   │   ├── install_spark.sh
│   │   └── setup_jupyter_kernel.sh
│   └── data/                     # Utilities
│       ├── snapshot_results.py
│       └── visualize_results.py
├── docs/                      # Tài liệu
│   ├── cai-dat.md                # Hướng dẫn cài đặt
│   ├── cau-truc.md               # Cấu trúc dự án
│   ├── hadoop-alternatives.md    # So sánh phương pháp
│   ├── huong-dan.md              # Hướng dẫn chạy
│   ├── jupyter.md                # Setup Jupyter
│   ├── migration.md              # Migration guide
│   └── tong-quan.md              # Tổng quan dự án
├── logs/                      # Logs
├── snapshots/                 # Snapshots
├── visualizations/            # Visualization
│   ├── phan-tich.ipynb           # Notebook phân tích
│   └── README.md
├── BAO_CAO_DU_AN.md              # Báo cáo chính (gộp)
├── changelog.md                  # Lịch sử thay đổi
├── README.md                     # File này
└── requirements.txt              # Dependencies
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

### Workflow

```text
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│ Raw CSV     │ ───> │ Temp Files   │ ───> │ HDFS        │
│ (data/   │      │ (tạm thời)   │      │ (permanent) │
│  raw/)      │      │              │      │             │
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

### Lưu ý

- ✅ Temp files tự động bị xóa sau khi upload HDFS
- ✅ Dữ liệu chính chỉ tồn tại trên HDFS
- ✅ Chỉ lưu kết quả phân tích nhỏ ở local (centroid, logs)
- ⚠️ Có thể sửa `HDFS_BASE` trong scripts nếu dùng cluster khác

<a id="chay-pipeline"></a>
## Chạy Pipeline

### Quick Start

```bash
# Chạy toàn bộ pipeline (V2 khuyến nghị)
./scripts/pipeline/full_pipeline_spark_v2.sh

# Tùy chọn flags (KMeans):
#   --seed N       : đặt seed (vd 42)
#   --k N          : số cụm K (vd 5)
#   --max-iter N   : số vòng lặp tối đa (vd 15)
#   --tol FLOAT    : ngưỡng hội tụ (vd 1e-4)
# Điều khiển luồng:
#   --reset, --from-step N, --skip-step N, --dry-run

# Ví dụ: K=6, maxIter=20, seed=33, tol=1e-5
./scripts/pipeline/full_pipeline_spark_v2.sh --k 6 --max-iter 20 --seed 33 --tol 1e-5
```

Pipeline sẽ tự động:
1. Khám phá dữ liệu với Polars
2. Chuẩn bị features và normalize
3. Upload lên HDFS (và xóa temp files)
4. Chạy K-means MLlib trên Spark (⚡ k-means++)
5. Tải kết quả và phân tích

### Manual Steps (nếu cần debug)

```bash
# 1. Khám phá dữ liệu
python scripts/polars/explore_fast.py

# 2. Chuẩn bị features (tạo temp files)
python scripts/polars/prepare_polars.py

# 3. Upload lên HDFS và XÓA temp files
scripts/spark/setup_hdfs.sh

# 4. Chạy Spark MLlib K-means trên HDFS (⚡ k-means++ auto)
scripts/spark/run_spark.sh

# 5. (Tùy chọn) Tải kết quả về
scripts/spark/download_from_hdfs.sh

# 6. Gán clusters
python scripts/polars/assign_clusters_polars.py

# 7. Phân tích kết quả
python scripts/polars/analyze.py

# 8. (Tùy chọn) Tạo snapshot kết quả
python scripts/data/snapshot_results.py

# 9. (Tùy chọn) Trực quan hóa
python scripts/data/visualize_results.py
```

### Logs & Snapshots

Logs được lưu tại `logs/pipeline_log_*.md` với timestamp.
Snapshots được lưu tại `snapshots/snapshot_*/` với timestamp.
Visualization được lưu tại `visualizations/`.

#### Latest snapshot

- Tên: `snapshot_20251029_213229`
- Thời gian: `2025-10-29 21:32:30`
- Kích thước: `342.75 MB`
- Đường dẫn: `snapshots/snapshot_20251029_213229/`
- Files:
  - `final_centroids.txt` (436 bytes)
  - `clustered_results.txt` (342.75 MB)
  - `suspicious_transactions.csv` (558 bytes)
  - `pipeline_log.md`

Tham chiếu: xem báo cáo cập nhật trong `bao_cao_du_an.md`.

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

### Cấu trúc HDFS

```text
/user/spark/hi_large/
├── input/
│   └── hadoop_input.txt      # Dữ liệu đã normalize (~33GB)
└── output_centroids/         # Final centroids từ MLlib (k-means++)
    └── part-00000
```

### Kiểm tra dữ liệu

```bash path=null start=null
# Xem cấu trúc
hdfs dfs -ls /user/spark/hi_large/

# Kiểm tra kích thước
hdfs dfs -du -h /user/spark/hi_large/

# Xem nội dung centroids
hdfs dfs -cat /user/spark/hi_large/output_centroids/part-00000
```

### Download kết quả (tùy chọn)

Kết quả nhỏ được tải về `data/results/` để phân tích local.

### Snapshots & Visualizations

```bash
# Tạo snapshot kết quả hiện tại
python scripts/data/snapshot_results.py

# Xem danh sách snapshots
python scripts/data/snapshot_results.py --list

# Tạo biểu đồ trực quan
python scripts/data/visualize_results.py
```

<a id="chi-tiet-steps"></a>
## Chi tiết Pipeline Steps

| Bước | Script | Mô tả | Thời gian |
|------|--------|-------|----------|
| 1 | `scripts/polars/explore_fast.py` | Khám phá dữ liệu nhanh | ~30s |
| 2 | `scripts/polars/prepare_polars.py` | Feature engineering & normalize | ~10 phút |
| 3 | `scripts/spark/setup_hdfs.sh` | Upload HDFS & xóa temp files | ~5 phút |
| 4 | `scripts/spark/run_spark.sh` | K-means MLlib (⚡ k-means++) | ~10-15 phút |
| 5 | `scripts/spark/download_from_hdfs.sh` | Tải centroids từ HDFS | ~30s |
| 6 | `scripts/polars/assign_clusters_polars.py` | Gán clusters cho data | ~10 phút |
| 7 | `scripts/polars/analyze.py` | Phân tích & báo cáo | ~2 phút |
| 8 | `scripts/data/snapshot_results.py` | Snapshot kết quả | ~10s |
| 9 | `scripts/data/visualize_results.py` | Tạo biểu đồ trực quan | ~2 phút |

**Tổng thời gian**: ~30-40 phút (⚡ Nhanh hơn 30-50% nhờ MLlib!)

<a id="kien-truc"></a>
## Kiến trúc hệ thống

```text
┌──────────────────────────────────────────────────────────────────┐
│                     HDFS-Only Workflow                           │
└──────────────────────────────────────────────────────────────────┘

    RAW CSV              POLARS              HDFS             SPARK
       │                   │                  │                │
   ┌───▼────┐         ┌───▼────┐        ┌───▼────┐       ┌───▼────┐
   │16GB CSV│────────>│ Temp   │───────>│ 33GB   │──────>│K-means │
   │data/│         │ Files  │ upload │Storage │ read  │Cluster │
   │  raw/  │         │        │        │        │       │        │
   └────────┘         └────────┘        └────────┘       └────────┘
                           │                                   │
                           │ (auto delete)                     │
                           ▼                                   ▼
                      [Xóa ngay]                       [Results HDFS]
                                                              │
                        ┌─────────────────────────────────────┤
                        │                                     │
                        ▼                                     ▼
               ┌─────────────────┐                  ┌─────────────────┐
               │ data/results/│                  │  snapshots/  │
               │  (small files)  │                  │  visualizations/│
               └─────────────────┘                  └─────────────────┘
```

### Đặc điểm

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
