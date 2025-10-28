# Changelog

## [2025-10-28] - Major Restructuring

### 🔄 Cấu trúc thư mục mới

#### Đã tổ chức lại scripts theo chức năng:

**`scripts/polars/`** - Data processing với Polars
- `explore_fast.py` - Khám phá dữ liệu nhanh
- `prepare_polars.py` - Feature engineering & normalization
- `init_centroids.py` - Khởi tạo centroids cho K-means
- `assign_clusters_polars.py` - Gán nhãn cluster cho dữ liệu
- `analyze_polars.py` - Phân tích kết quả clustering

**`scripts/spark/`** - PySpark K-means implementation
- `setup_hdfs.sh` - Upload dữ liệu lên HDFS
- `run_spark.sh` - Chạy Spark K-means trên HDFS
- `kmeans_spark.py` - PySpark K-means implementation
- `download_from_hdfs.sh` - Tải kết quả từ HDFS

**`scripts/pipeline/`** - Pipeline orchestration
- `full_pipeline_spark.sh` - Chạy toàn bộ pipeline
- `clean_spark.sh` - Dọn dẹp project
- `reset_pipeline.sh` - Reset checkpoints

**`scripts/setup/`** - Installation & setup
- `install_spark.sh` - Cài đặt Apache Spark

### ♻️ Chuyển sang HDFS-only workflow

#### Không lưu dữ liệu lớn ở local:
- `prepare_polars.py` tạo temp files thay vì file vĩnh viễn
- `init_centroids.py` tạo temp files thay vì file vĩnh viễn
- `setup_hdfs.sh` tự động xóa temp files sau khi upload HDFS
- Dữ liệu chỉ tồn tại trên HDFS

### 🗄️ Archive legacy code

**`archive/`** - Không còn sử dụng
- `hadoop/` - MapReduce implementation (legacy)
- `full_pipeline.sh` - Hadoop pipeline (legacy)
- `clean_outputs.sh` - Old cleanup script (legacy)

### 📝 Cập nhật documentation

#### README.md:
- Cập nhật cấu trúc thư mục mới
- Cập nhật hướng dẫn sử dụng với đường dẫn mới
- Nhấn mạnh HDFS-only workflow
- Xóa hướng dẫn Hadoop legacy

#### Paths đã thay đổi:
```bash
# CŨ
./scripts/full_pipeline_spark.sh
./scripts/clean_spark.sh
python scripts/prepare_polars.py

# MỚI
./scripts/pipeline/full_pipeline_spark.sh
./scripts/pipeline/clean_spark.sh
python scripts/polars/prepare_polars.py
```

### ✨ Lợi ích của cấu trúc mới

1. **Dễ điều hướng**: Các file được nhóm theo chức năng
2. **Rõ ràng hơn**: Biết ngay file nào thuộc module nào
3. **Dễ bảo trì**: Thêm/sửa/xóa file dễ dàng hơn
4. **Tuân thủ quy tắc**: Không lưu dữ liệu lớn local

### ⚠️ Breaking Changes

Tất cả đường dẫn scripts đã thay đổi. Cần cập nhật:
- Automation scripts
- CI/CD pipelines
- Documentation references
- Shortcuts/aliases
