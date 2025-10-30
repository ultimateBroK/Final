# Project Overview: HI-Large Transaction Analysis

## 📋 Mô tả Project

Pipeline phân tích dữ liệu giao dịch HI-Large_Trans.csv (16GB, 179M transactions) để phát hiện giao dịch rửa tiền sử dụng K-means clustering.

### Công nghệ sử dụng:
- **Polars**: Xử lý dữ liệu nhanh (feature engineering)
- **Apache Spark**: Distributed K-means clustering
- **HDFS**: Lưu trữ dữ liệu (tuân thủ quy định không lưu local)

---

## 🎯 Mục tiêu

1. Phân tích 179M giao dịch từ file CSV 16GB
2. Clustering bằng K-means để nhóm các pattern giao dịch
3. Phát hiện clusters có tỷ lệ rửa tiền cao
4. **KHÔNG lưu dữ liệu lớn ở local** (chỉ trên HDFS)

---

## 🏗️ Kiến trúc

```
┌─────────────────────────────────────────────────────────────┐
│                    HDFS-Only Architecture                    │
└─────────────────────────────────────────────────────────────┘

  INPUT              PROCESSING           STORAGE          COMPUTE
    │                    │                   │                │
┌───▼────┐         ┌───▼────┐         ┌────▼────┐      ┌───▼────┐
│16GB CSV│ ──────> │ Polars │ ──────> │  HDFS   │ ───> │ Spark  │
│Raw Data│         │Features│  Upload │ 33GB    │ Read │K-means │
└────────┘         └────────┘         └─────────┘      └────────┘
                        │                                    │
                        │ (auto delete)                      │
                        ▼                                    ▼
                  [Temp Deleted]                    [Results HDFS]
                                                           │
                                                           ▼
                                                   ┌──────────────┐
                                                   │data/results/ │
                                                   │(small files) │
                                                   └──────────────┘
```

### Nguyên tắc thiết kế:

✅ **Temp files tự động xóa** - Không lưu dữ liệu lớn local  
✅ **HDFS-only storage** - Tuân thủ quy định  
✅ **Distributed processing** - Spark xử lý song song  
✅ **Fault-tolerant** - HDFS replication

---

## 📂 Cấu trúc Project

```
Final/
├── data/
│   ├── raw/                    # Input: HI-Large_Trans.csv (16GB)
│   ├── processed/              # Temp (tự động xóa sau upload)
│   └── results/                # Kết quả nhỏ từ HDFS
│
|├── scripts/
│   ├── polars/                 # Data processing
│   │   ├── explore_fast.py         → Khám phá dữ liệu
│   │   ├── prepare_polars.py       → Feature engineering
│   │   ├── assign_clusters_polars.py → Gán labels
│   │   └── analyze_polars.py       → Phân tích kết quả
│   │
│   ├── spark/                  # Distributed computing
│   │   ├── setup_hdfs.sh           → Upload & delete temps
│   │   ├── run_spark.sh            → Chạy Spark job
│   │   ├── kmeans_spark.py         → PySpark K-means
│   │   └── download_from_hdfs.sh   → Tải kết quả
│   │
│   ├── pipeline/               # Orchestration
│   │   ├── full_pipeline_spark.sh  → Toàn bộ pipeline
│   │   ├── clean_spark.sh          → Dọn dẹp project
│   │   └── reset_pipeline.sh       → Reset checkpoints
│   │
│   └── setup/
│       └── (manual per docs)
│
├── docs/
│   ├── tong-quan.md                → Document này
│   ├── hadoop-alternatives.md      → So sánh phương pháp
│   └── jupyter.md                  → Notebook/Jupyter hướng dẫn
│
├── logs/                       # Pipeline logs
├── archive/hadoop/             # Legacy MapReduce code
├── CHANGELOG.md
└── README.md
```

---

## 🔄 Pipeline Workflow

### Tổng quan 7 bước:

```
[1] Explore → [2] Prepare → [3] Upload → [4] Spark (MLlib) → [5] Download → [6] Assign → [7] Analyze
     30s        10 min      5 min      10-25 min           30s         10 min      2 min
```

⚠️ **Thay đổi quan trọng**: Bước khởi tạo centroids (bước 3 cũ) đã **loại bỏ** vì MLlib K-means tự động dùng **k-means++**!

### Chi tiết từng bước:

#### 1. Explore Data (`explore_fast.py`)
- Scan CSV với Polars (lazy loading)
- Xem schema, sample, distribution
- **Thời gian**: ~30 giây

#### 2. Feature Engineering (`prepare_polars.py`)
- Parse timestamp → hour, day_of_week
- Tính amount_ratio, route_hash
- Encode categorical features
- Normalize tất cả features
- **Output**: `data/processed/hadoop_input.txt` (temp)
- **Thời gian**: ~10 phút

#### ~~3. Initialize Centroids~~ ❌ **ĐÃ LOẠI BỎ**
- MLlib K-means tự động sử dụng k-means++ để khởi tạo centroids
- Không cần file `centroids.txt` nữa
- Tiết kiệm 30 giây và cho kết quả tốt hơn

#### 3. Upload to HDFS (`setup_hdfs.sh`)
- Upload hadoop_input.txt → `/user/spark/hi_large/input/`
- **XÓA tự động** temp files từ `data/processed/`
- **Thời gian**: ~5 phút

#### 4. Spark K-means (`run_spark.sh`)
- Chạy `kmeans_spark.py` với spark-submit
- Đọc dữ liệu từ HDFS
- **MLlib K-means với k-means++ initialization**
- Lưu final centroids trên HDFS
- **Thời gian**: 10-25 phút (nhanh hơn 30-50% nhờ MLlib!)

#### 5. Download Results (`download_from_hdfs.sh`)
- Tải final centroids từ HDFS
- Lưu vào `data/results/final_centroids.txt`
- **Thời gian**: ~30 giây

#### 6. Assign Clusters (`assign_clusters_polars.py`)
- Đọc raw CSV + final centroids
- Tính khoảng cách, gán cluster cho mỗi transaction
- **Output**: `data/results/clustered_results.txt`
- **Thời gian**: ~10 phút

#### 7. Analyze (`analyze_polars.py`)
- Phân tích tỷ lệ laundering per cluster
- Tìm high-risk clusters (>10% laundering)
- Export suspicious transactions
- **Output**: Reports, suspicious_transactions.csv
- **Thời gian**: ~2 phút

---

## ⚡ Quick Start

### Cài đặt:

```bash
# 1. Cài Spark
./scripts/setup/install_spark.sh
source ~/.zshrc

# 2. Cài Python packages
pip install polars numpy pyspark

# 3. Đặt CSV vào data/raw/
cp /path/to/HI-Large_Trans.csv data/raw/
```

### Chạy Pipeline:

```bash
# Toàn bộ pipeline tự động
./scripts/pipeline/full_pipeline_spark.sh

# Log sẽ lưu tại: logs/pipeline_log_*.md
```

### Dọn dẹp:

```bash
# Reset toàn bộ
./scripts/pipeline/clean_spark.sh

# Chỉ reset checkpoints
./scripts/pipeline/reset_pipeline.sh
```

---

## 📊 HDFS Data Structure

```
/user/spark/hi_large/
├── input/
│   └── hadoop_input.txt        # 33GB normalized data
├── centroids.txt               # (legacy) initial centroids (không bắt buộc)
└── output_centroids/           # Final centroids after convergence
    └── part-00000
```

### Kiểm tra:

```bash
# List files
hdfs dfs -ls -R /user/spark/hi_large/

# Kiểm tra kích thước
hdfs dfs -du -h /user/spark/hi_large/

# Xem centroids
hdfs dfs -cat /user/spark/hi_large/output_centroids/part-00000
```

---

## 🎯 Performance

### Thời gian ước tính:

| Bước | Thời gian | Tool |
|------|-----------|------|
| 1. Explore | 30s | Polars |
| 2. Prepare | 10 min | Polars |
| ~~3. Init~~ | ~~30s~~ (loại bỏ) | ~~NumPy~~ |
| 3. Upload | 5 min | HDFS |
| 4. K-means | 10-25 min | Spark MLlib |
| 5. Download | 30s | HDFS |
| 6. Assign | 10 min | Polars + NumPy |
| 7. Analyze | 2 min | Polars |
| **TOTAL** | **~35-50 min** | (nhanh hơn 30-50%) |

### So sánh với Hadoop MapReduce:

- Hadoop legacy: **1-2 giờ** (chỉ K-means)
- Spark RDD (cũ): **15-30 phút** (chỉ K-means)
- **Spark MLlib (mới)**: **10-25 phút** (chễ K-means)
- **Tăng tốc tổng**: 5-12x so với Hadoop, 30-50% so với RDD

---

## 🆕 Snapshot gần nhất

- Tên snapshot: `snapshot_20251030_095037`
- Thời gian: `2025-10-30 09:50:37`
- Thư mục: `snapshots/snapshot_20251030_095037/`
- Thành phần:
  - `final_centroids.txt`
  - `clustered_results.txt`
  - `suspicious_transactions.csv`
  - `pipeline_log.md`

Tham khảo báo cáo chi tiết: `bao_cao_du_an.md` (đã đồng bộ theo snapshot này).

## 🛡️ Quy tắc HDFS-Only

### ✅ ĐƯỢC PHÉP lưu local:

- Raw CSV ban đầu (`data/raw/`)
- Kết quả nhỏ từ HDFS (`data/results/`)
- Logs (`logs/`)
- Code, docs

### ❌ KHÔNG ĐƯỢC lưu local:

- Dữ liệu đã xử lý (hadoop_input.txt)
- Intermediate results
- Large temporary files

### 🔄 Workflow tuân thủ:

1. Polars tạo temp files trong `data/processed/`
2. `setup_hdfs.sh` upload lên HDFS
3. Script **TỰ ĐỘNG XÓA** temp files ngay sau upload
4. Dữ liệu chỉ tồn tại trên HDFS
5. MLlib K-means tự động khởi tạo centroids với k-means++
6. Chỉ tải về kết quả nhỏ (centroids, reports)

---

## 🔧 Troubleshooting

### Pipeline fails ở bước 4 (upload HDFS):

```bash
# Kiểm tra HDFS running
hdfs dfsadmin -report

# Kiểm tra permissions
hdfs dfs -ls /user/spark/

# Tạo directory nếu chưa có
hdfs dfs -mkdir -p /user/spark/hi_large/input
```

### Out of memory trong Spark:

Sửa `scripts/spark/run_spark.sh`:

```bash
--driver-memory 8g \        # Tăng từ 4g
--executor-memory 8g \      # Tăng từ 4g
```

### Temp files không tự động xóa:

Kiểm tra `scripts/spark/setup_hdfs.sh`:

```bash
# Đảm bảo có dòng này ở cuối script:
rm -rf "$PROJECT_ROOT/data/processed/"*
```

### Polars báo lỗi memory:

Giảm batch size hoặc dùng lazy mode:

```python
# Thay vì read_csv
df = pl.scan_csv('file.csv')  # Lazy
df.sink_csv('output.csv')     # Stream to disk
```

---

## 📈 Monitoring

### Xem logs pipeline:

```bash
# Log mới nhất
tail -f logs/pipeline_log_*.md

# Grep errors
grep "ERROR\|FAILED" logs/pipeline_log_*.md
```

### Monitor Spark job:

```bash
# Spark UI (nếu chạy)
# Mở browser: http://localhost:4040

# Xem Spark history
spark-history-server start
# Browser: http://localhost:18080
```

### Checkpoints:

Pipeline sử dụng checkpoints để tránh chạy lại các bước đã hoàn thành:

```bash
# Xem checkpoints
ls -la .pipeline_checkpoints/

# Reset để chạy lại từ đầu
./scripts/pipeline/reset_pipeline.sh
```

---

## 🎓 Tài liệu tham khảo

- **README.md**: Quick start guide
- **hadoop-alternatives.md**: So sánh các phương pháp clustering
- **jupyter.md**: Hướng dẫn Jupyter/Notebook
- **changelog.md**: Lịch sử thay đổi project

---

## 👥 Development Guidelines

### Thêm bước mới vào pipeline:

1. Tạo script trong thư mục phù hợp (`scripts/polars/` hoặc `scripts/spark/`)
2. Cập nhật `scripts/pipeline/full_pipeline_spark.sh`
3. Thêm checkpoint nếu cần
4. Update docs (README.md, tong-quan.md)

### Testing:

```bash
# Test từng bước riêng lẻ
python scripts/polars/explore_fast.py

# Test với sample nhỏ
head -n 100000 data/raw/HI-Large_Trans.csv > data/raw/sample.csv
# Sửa scripts để đọc sample.csv
```

### Git workflow:

```bash
# Không commit large files
git add scripts/ docs/ README.md CHANGELOG.md
git commit -m "Update documentation"

# Ignore data files (đã có trong .gitignore)
```

---

## 📞 Support

Nếu gặp vấn đề:

1. Kiểm tra logs: `logs/pipeline_log_*.md`
2. Xem troubleshooting section ở trên
3. Kiểm tra HDFS status: `hdfs dfsadmin -report`
4. Check Spark UI: http://localhost:4040

---

**Last Updated**: 2025-10-30  
**Project Version**: 2.1 (Spark MLlib)
