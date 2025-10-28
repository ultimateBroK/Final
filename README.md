# Polars + PySpark Pipeline

Pipeline phân tích dữ liệu HI-Large_Trans.csv sử dụng Polars và Apache Spark (PySpark).

## ⚡ Nâng cấp từ Hadoop sang Spark

Project đã được cập nhật để sử dụng **Apache Spark** thay vì Hadoop MapReduce, giúp:
- ⚡ **Xử lý nhanh hơn** nhiều lần (in-memory computing)
- 🔧 **Dễ cài đặt hơn** (không cần HDFS)
- 📝 **Code đơn giản hơn** (PySpark API)
- 🚀 **Scale tốt hơn** với big data

## Cấu trúc thư mục (ADHD-friendly)

```
data/
  raw/                # Input gốc (CSV lớn)
  processed/          # Temp files (xóa sau khi upload HDFS)
  results/            # Kết quả tải về từ HDFS (tùy chọn)
docs/                 # Tài liệu
logs/                 # Log pipeline
scripts/
  polars/             # Data processing với Polars
    └─ explore_fast.py, prepare_polars.py, init_centroids.py,
       assign_clusters_polars.py, analyze_polars.py
  spark/              # PySpark K-means implementation
    └─ setup_hdfs.sh, run_spark.sh, kmeans_spark.py,
       download_from_hdfs.sh
  pipeline/           # Pipeline orchestration
    └─ full_pipeline_spark.sh, clean_spark.sh, reset_pipeline.sh
  setup/              # Installation scripts
    └─ install_spark.sh
archive/              # Legacy Hadoop code (không dùng)
```

## Cài đặt Apache Spark

```bash
# Chạy script cài đặt (CachyOS/Arch Linux)
./scripts/setup/install_spark.sh

# Sau khi cài đặt, reload shell
source ~/.zshrc

# Kiểm tra cài đặt
spark-submit --version
```

## Chuẩn bị dữ liệu

- Đặt file CSV vào: `data/raw/HI-Large_Trans.csv`

## ⚠️ QUAN TRỌNG: Dữ liệu chỉ lưu trên HDFS

Project này **KHÔNG lưu dữ liệu lớn ở local**. Tất cả dữ liệu đều được xử lý và lưu trên HDFS.

### Quy trình làm việc:

```bash
# 1) Chuẩn bị dữ liệu (tạo temp file)
cd scripts/polars
python prepare_polars.py
python init_centroids.py

# 2) Upload lên HDFS và XÓA temp files local
../spark/setup_hdfs.sh

# 3) Chạy Spark trên HDFS (YARN/cluster)
../spark/run_spark.sh

# 4) (Tuỳ chọn) Tải kết quả về để phân tích
../spark/download_from_hdfs.sh
```

**Lưu ý:**
- Temp files sẽ tự động bị XÓA sau khi upload lên HDFS
- Dữ liệu chỉ tồn tại trên HDFS, không trên local
- Bạn có thể sửa `HDFS_BASE` trong các script nếu dùng cluster khác

## Chạy Pipeline

```bash
# Toàn bộ pipeline với PySpark + HDFS
./scripts/pipeline/full_pipeline_spark.sh
```

Log sẽ lưu tại `logs/pipeline_log_*.md`.

**Hadoop legacy code đã được archive** - không còn sử dụng nữa.

## Clean Project

```bash
# Dọn dẹp toàn bộ để chạy lại từ đầu
./scripts/pipeline/clean_spark.sh

# Sau đó chạy lại pipeline
./scripts/pipeline/full_pipeline_spark.sh
```

## Dữ liệu trên HDFS

Tất cả dữ liệu được lưu trên HDFS tại: `/user/spark/hi_large/`

- `input/hadoop_input.txt` - Dữ liệu đã normalize
- `centroids.txt` - Centroids ban đầu  
- `output_centroids/` - Centroids cuối cùng từ Spark
- Kết quả được tải về `data/results/` khi cần phân tích

## Pipeline Steps

1. **`scripts/polars/explore_fast.py`** - Khám phá dữ liệu
2. **`scripts/polars/prepare_polars.py`** - Feature engineering (tạo temp file)
3. **`scripts/polars/init_centroids.py`** - Khởi tạo centroids (temp file)
4. **`scripts/spark/setup_hdfs.sh`** - Upload lên HDFS & xóa temp files 💾
5. **`scripts/spark/run_spark.sh`** - K-means với PySpark trên HDFS ⚡
6. **`scripts/spark/download_from_hdfs.sh`** - Tải kết quả về (tùy chọn)
7. **`scripts/polars/assign_clusters_polars.py`** - Gán nhãn cluster
8. **`scripts/polars/analyze_polars.py`** - Phân tích kết quả

## Kiến trúc: HDFS-Only Workflow

```
[Temp Local] --> [Upload + Delete] --> [Spark on HDFS] --> [Results on HDFS]
      │                   │                     │                    │
   Polars          setup_hdfs.sh           PySpark         (download nếu cần)
  (temp file)      (xóa ngay)           (in-memory)      
```

- ✅ **KHÔNG lưu dữ liệu lớn local** - Temp files tự động xóa
- ✅ **Dữ liệu chỉ trên HDFS** - Tuân thủ quy tắc lưu trữ
- ✅ **Distributed processing** - Spark xử lý song song
- ✅ **Scalable** - Thêm nodes để tăng performance

## So sánh Hadoop vs Spark

| Tiêu chí | Hadoop MapReduce | Apache Spark (HDFS) |
|----------|------------------|---------------------|
| **Tốc độ** | Chậm (đọc/ghi disk) | Nhanh hơn 10-100x |
| **Storage** | HDFS | HDFS |
| **Processing** | Disk-based | In-memory |
| **Code** | Dài (mapper/reducer) | Ngắn gọn (PySpark API) |
| **Phù hợp** | Batch processing lớn | Iterative algorithms |

## Lợi ích khi dùng Spark

- ⚡ **Nhanh hơn 10-100x** với iterative algorithms như K-means
- 💾 **In-memory processing** - giảm I/O disk
- 🎯 **API đơn giản** - code ngắn gọn hơn
- 🔧 **Dễ debug** - chạy local không cần cluster
