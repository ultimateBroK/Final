# MIGRATION GUIDE - CẬP NHẬT CẤU TRÚC DỰ ÁN

## 📝 Tổng quan

Dự án đã được tổ chức lại với cấu trúc xếp theo thứ tự khoa học để dễ theo dõi và quản lý.

**Ngày cập nhật:** 2025-10-29  
**Phiên bản:** 2.0

---

## 🔄 Thay đổi cấu trúc

### Folders đã đổi tên

| Tên cũ | Tên mới | Mục đích |
|--------|---------|----------|
| `data/` | `01_data/` | Dữ liệu (raw, processed, results) |
| `scripts/` | `02_scripts/` | Scripts xếp theo thứ tự |
| `docs/` | `03_docs/` | Tài liệu |
| `logs/` | `04_logs/` | Logs với timestamp |
| *(mới)* | `05_snapshots/` | Lưu kết quả mỗi lần chạy |
| *(mới)* | `06_visualizations/` | Biểu đồ trực quan |

### Scripts đã đổi tên (02_scripts/polars/)

| Tên cũ | Tên mới |
|--------|------|
| `explore_fast.py` | `explore_fast.py` |
| `prepare_polars.py` | `prepare_polars.py` |
| ~~`init_centroids.py`~~ | ❌ **Đã loại bỏ** (MLlib tự động dùng k-means++) |
| `assign_clusters_polars.py` | `03_assign_clusters.py` |
| `analyze_polars.py` | `04_analyze.py` |

### Scripts mới

| File | Mô tả |
|------|-------|
| `02_scripts/data/snapshot_results.py` | Tự động snapshot kết quả |
| `02_scripts/data/visualize_results.py` | Tạo biểu đồ trực quan |

---

## 📋 Mapping đường dẫn

### Đường dẫn dữ liệu

```bash
# CŨ → MỚI
data/raw/                  → 01_data/raw/
data/processed/            → 01_data/processed/
data/results/              → 01_data/results/
```

### Đường dẫn scripts

```bash
# CŨ → MỚI
scripts/polars/explore_fast.py          → 02_scripts/polars/explore_fast.py
scripts/polars/prepare_polars.py        → 02_scripts/polars/prepare_polars.py
# scripts/polars/init_centroids.py      → ❌ ĐÃ LOẠI BỎ (MLlib k-means++ tự động)
scripts/polars/assign_clusters_polars.py → 02_scripts/polars/03_assign_clusters.py
scripts/polars/analyze_polars.py        → 02_scripts/polars/04_analyze.py

scripts/spark/setup_hdfs.sh             → 02_scripts/spark/setup_hdfs.sh
scripts/spark/run_spark.sh              → 02_scripts/spark/run_spark.sh
scripts/spark/download_from_hdfs.sh     → 02_scripts/spark/download_from_hdfs.sh

scripts/pipeline/full_pipeline_spark.sh → 02_scripts/pipeline/full_pipeline_spark.sh
scripts/pipeline/clean_spark.sh         → 02_scripts/pipeline/clean_spark.sh
scripts/pipeline/reset_pipeline.sh      → 02_scripts/pipeline/reset_pipeline.sh
```

### Đường dẫn logs

```bash
# CŨ → MỚI
logs/pipeline_log_*.md     → 04_logs/pipeline_log_*.md
```

---

## 🚀 Cách sử dụng sau migration

### Chạy pipeline

```bash
# CŨ
./scripts/pipeline/full_pipeline_spark.sh

# MỚI
./02_scripts/pipeline/full_pipeline_spark.sh
```

### Chạy từng bước

```bash
# CŨ
python scripts/polars/explore_fast.py
python scripts/polars/prepare_polars.py
# ... etc

# MỚI
python 02_scripts/polars/explore_fast.py
python 02_scripts/polars/prepare_polars.py
# (Bước 3 init centroids đã loại bỏ)
python 02_scripts/polars/03_assign_clusters.py
python 02_scripts/polars/04_analyze.py
```

### Snapshot và visualization

```bash
# Tạo snapshot (MỚI)
python 02_scripts/data/snapshot_results.py

# Xem danh sách snapshots
python 02_scripts/data/snapshot_results.py --list

# Tạo visualization (MỚI)
python 02_scripts/data/visualize_results.py
```

### Cleanup

```bash
# CŨ
./scripts/pipeline/clean_spark.sh

# MỚI
./02_scripts/pipeline/clean_spark.sh
```

---

## ✅ Checklist migration

- [x] Di chuyển folders cũ sang folders mới
- [x] Đổi tên scripts với số prefix
- [x] Cập nhật paths trong tất cả Python scripts
- [x] Cập nhật paths trong tất cả shell scripts
- [x] Cập nhật README.md
- [x] Tạo scripts mới (snapshot, visualize)
- [x] Tạo CAU_TRUC_DU_AN.md
- [x] Test pipeline (chưa test)

---

## 🎯 Lợi ích của cấu trúc mới

### 1. **Xếp theo thứ tự logic**
- Folders có prefix số (01_, 02_, ...) → dễ hiểu workflow
- Scripts có prefix số → biết thứ tự chạy

### 2. **Snapshot tự động**
- Lưu kết quả mỗi lần chạy thành công
- So sánh kết quả qua các lần chạy
- Có metadata để tracking

### 3. **Visualization**
- Biểu đồ ASCII dễ xem trên terminal
- Báo cáo markdown format
- Không cần GUI tools

### 4. **Tổ chức tốt hơn**
- Logs riêng folder
- Snapshots riêng folder
- Visualizations riêng folder
- Dễ backup và quản lý

---

## ⚠️ Lưu ý

### Checkpoints
Nếu bạn đang chạy pipeline dở, cần reset checkpoints:

```bash
./02_scripts/pipeline/reset_pipeline.sh all
```

### HDFS
Dữ liệu trên HDFS không bị ảnh hưởng, vẫn ở:
- `/user/spark/hi_large/input/`
- `/user/spark/hi_large/centroids.txt`
- `/user/spark/hi_large/output_centroids/`

### Virtual Environment
`.venv` không thay đổi, không cần cài lại packages.

---

## 📚 Tài liệu

Xem chi tiết cấu trúc mới tại:
- **CAU_TRUC_DU_AN.md** - Giải thích đầy đủ
- **README.md** - Hướng dẫn tổng quan (đã cập nhật)
- **HUONG_DAN_CHAY.md** - Chi tiết từng bước (cần cập nhật)

---

## 🆘 Troubleshooting

### Lỗi: "No such file or directory"
Có thể bạn đang dùng lệnh cũ. Kiểm tra lại paths:
- Dùng `01_data/` thay vì `data/`
- Dùng `02_scripts/` thay vì `scripts/`

### Lỗi: Permission denied
Đảm bảo scripts có quyền executable:
```bash
chmod +x 02_scripts/pipeline/*.sh
chmod +x 02_scripts/spark/*.sh
chmod +x 02_scripts/data/*.py
```

### Reset toàn bộ
Nếu gặp vấn đề, reset và chạy lại:
```bash
./02_scripts/pipeline/clean_spark.sh
./02_scripts/pipeline/full_pipeline_spark.sh
```

---

**Cập nhật cuối:** 2025-10-29  
**Người thực hiện:** AI Assistant
