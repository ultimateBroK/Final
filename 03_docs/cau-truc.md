# CẤU TRÚC DỰ ÁN - FINAL

Dự án phân tích phát hiện rửa tiền sử dụng K-means clustering với Apache Spark + Polars.

## 📁 Cấu trúc thư mục (Xếp theo thứ tự)

```
Final/
├── 01_data/                      # DỮ LIỆU
│   ├── raw/                      # Dữ liệu gốc (16GB CSV)
│   ├── processed/                # Files tạm (tự động xóa sau upload HDFS)
│   └── results/                  # Kết quả nhỏ từ HDFS
│
├── 02_scripts/                   # SCRIPTS (Xếp theo thứ tự chạy)
│   ├── polars/                   # Data processing với Polars
│   │   ├── explore_fast.py       # Bước 1: Khám phá dữ liệu
│   │   ├── prepare_polars.py     # Bước 2: Feature engineering
│   │   ├── assign_clusters_polars.py    # Bước 6: Gán nhãn clusters
│   │   └── analyze.py            # Bước 7: Phân tích kết quả
│   │
│   ├── spark/                    # PySpark MLlib (k-means++)
│   │   ├── setup_hdfs.sh         # Bước 3: Upload HDFS
│   │   ├── run_spark.sh          # Bước 4: Chạy K-means MLlib
│   │   ├── kmeans_spark.py       # Logic MLlib k-means++
│   │   └── download_from_hdfs.sh # Bước 5: Download kết quả
│   │
│   ├── pipeline/                 # Pipeline orchestration
│   │   ├── full_pipeline_spark.sh # Chạy toàn bộ pipeline
│   │   ├── clean_spark.sh        # Dọn dẹp project
│   │   └── reset_pipeline.sh     # Reset checkpoints
│   │
│   ├── setup/                    # Cài đặt môi trường
│   │   └── install_spark.sh      # Cài Apache Spark
│   │
│   └── data/                     # Data utilities
│       ├── snapshot_results.py   # Snapshot kết quả với timestamp
│       └── visualize_results.py  # Tạo biểu đồ trực quan
│
├── 03_docs/                      # TÀI LIỆU
│   ├── HADOOP_ALTERNATIVES.md    # So sánh các phương pháp clustering
│   └── PROJECT_OVERVIEW.md       # Tổng quan dự án
│
├── 04_logs/                      # LOGS
│   └── pipeline_log_*.md         # Logs với timestamp
│
├── 05_snapshots/                 # SNAPSHOTS
│   └── snapshot_YYYYMMDD_HHMMSS/ # Kết quả mỗi lần chạy thành công
│       ├── final_centroids.txt
│       ├── clustered_results.txt
│       ├── pipeline_log.md
│       └── metadata.json
│
├── 06_visualizations/            # BIỂU ĐỒ
│   ├── visual_report_*.md        # Báo cáo trực quan với timestamp
│   └── latest_summary.txt        # Tóm tắt kết quả mới nhất
│
├── README.md                     # Hướng dẫn tổng quan
├── HUONG_DAN_CHAY.md            # Hướng dẫn chi tiết từng bước
├── BAO_CAO_TIEU_LUAN.md         # Báo cáo đồ án
├── CHANGELOG.md                  # Lịch sử thay đổi
└── CAU_TRUC_DU_AN.md            # File này

```

## 🔄 Workflow Pipeline (9 bước - ⚡ Tối ưu với MLlib)

| Bước | Script | Input | Output | Mô tả |
|------|--------|-------|--------|-------|
| 1 | `explore_fast.py` | CSV gốc | Console | Khám phá dữ liệu |
| 2 | `prepare_polars.py` | CSV gốc | Temp files | Feature engineering |
| 3 | `setup_hdfs.sh` | Temp files | HDFS | Upload & **xóa temp** |
| 4 | `run_spark.sh` | HDFS | HDFS results | K-means MLlib (⚡ k-means++) |
| 5 | `download_from_hdfs.sh` | HDFS | final_centroids.txt | Download centroids |
| 6 | `assign_clusters_polars.py` | CSV + centroids | clustered_results.txt | Gán nhãn |
| 7 | `analyze.py` | Clustered data | Console + CSV | Phân tích |
| 8 | `snapshot_results.py` | Results folder | 05_snapshots/ | Lưu snapshot |
| 9 | `visualize_results.py` | Clustered data | 06_visualizations/ | Biểu đồ |

**⚡ Cải tiến:** MLlib tự động dùng k-means++ khởi tạo - không cần bước 3 nữa!

## 📊 Luồng dữ liệu

```
CSV gốc (16GB)
    ↓
[Polars processing]
    ↓
Temp files (33GB) → HDFS → [Spark K-means] → Results
    ↓ (tự động xóa)                               ↓
                                                  ↓
                                    ┌─────────────┴─────────────┐
                                    ↓                           ↓
                              01_data/results/           05_snapshots/
                              (kết quả mới)              (lịch sử)
                                    ↓
                            06_visualizations/
                            (biểu đồ)
```

## 🎯 Mục đích từng folder

### 01_data/
- **raw/**: Dữ liệu gốc, không thay đổi
- **processed/**: Tạm thời, tự động xóa sau upload HDFS
- **results/**: Kết quả nhỏ, được phép lưu local

### 02_scripts/
- Scripts xếp theo thứ tự chạy (01_, 02_, ...)
- Mỗi script độc lập, có thể chạy riêng để debug

### 05_snapshots/
- Tự động snapshot mỗi lần pipeline chạy thành công
- Format: `snapshot_YYYYMMDD_HHMMSS/`
- Bao gồm: centroids, clusters, logs, metadata

### 06_visualizations/
- Báo cáo trực quan với ASCII charts
- Dễ xem trên terminal
- Format Markdown

## 🚀 Quick Start

```bash
# Chạy toàn bộ pipeline
./02_scripts/pipeline/full_pipeline_spark.sh

# Sau khi hoàn tất:
# - Xem logs: 04_logs/pipeline_log_*.md
# - Xem snapshots: 05_snapshots/snapshot_*/
# - Xem biểu đồ: 06_visualizations/visual_report_*.md
```

## 🔄 Snapshot workflow

```bash
# Pipeline chạy thành công → Tự động:
# 1. Lưu kết quả vào 01_data/results/
# 2. Tạo snapshot trong 05_snapshots/
# 3. Tạo visualization trong 06_visualizations/

# Xem lại snapshots cũ:
python 02_scripts/data/snapshot_results.py --list

# Tạo snapshot thủ công:
python 02_scripts/data/snapshot_results.py

# Tạo visualization:
python 02_scripts/data/visualize_results.py
```

## 📝 Naming Convention

### Scripts
- Prefix số: `01_`, `02_`, ... (thứ tự thực thi)
- Động từ + danh từ: `explore_fast.py`, `prepare_polars.py`

### Folders
- Prefix số: `01_`, `02_`, ... (thứ tự logic)
- Tên ngắn gọn, mô tả rõ ràng

### Files
- Timestamp cho logs/snapshots: `YYYYMMDD_HHMMSS`
- Lowercase với underscore: `final_centroids.txt`

## ⚠️ Lưu ý quan trọng

1. **Không lưu dữ liệu lớn local**: Temp files tự động xóa sau upload HDFS
2. **Snapshots**: Lưu lịch sử kết quả để so sánh qua các lần chạy
   - Latest: `05_snapshots/snapshot_20251029_213229/` (342.75 MB, 2025-10-29 21:32:30)
3. **Visualizations**: Tạo báo cáo dễ đọc với ASCII charts
4. **Logs**: Mỗi lần chạy tạo log riêng với timestamp

## 📚 Tài liệu liên quan

- **README.md**: Hướng dẫn tổng quan
- **HUONG_DAN_CHAY.md**: Chi tiết từng bước
- **BAO_CAO_TIEU_LUAN.md**: Báo cáo đầy đủ

---

**Cập nhật**: 2025-10-29
**Phiên bản**: 2.1 (MLlib k-means++ - Nhanh hơn 30-50%)
