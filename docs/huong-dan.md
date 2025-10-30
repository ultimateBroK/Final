# 🚀 HƯỚNG DẪN CHẠY PIPELINE

## Mục lục
- [Giới thiệu](#gioi-thieu)
- [Chuẩn bị](#chuan-bi)
- [Pipeline 7 bước](#pipeline-7-buoc)
- [Chạy tự động](#chay-tu-dong)
- [Xử lý lỗi thường gặp](#loi-thuong-gap)
- [Xem kết quả](#xem-ket-qua)
- [Dọn dẹp sau khi xong](#don-dep)
- [Checklist trước khi chạy](#checklist)
- [Tài liệu tham khảo](#tai-lieu)

<a id="gioi-thieu"></a>
## Giới thiệu

Pipeline này xử lý 179 triệu giao dịch (16GB) để phát hiện rửa tiền bằng K-means clustering.

**Thời gian tổng**: ~35-50 phút  
**Công nghệ**: Polars + Apache Spark MLlib + HDFS

---

<a id="chuan-bi"></a>
## 📋 Chuẩn bị

### 1. Kiểm tra môi trường

```bash
# Java
java -version  # Cần version 11 hoặc 17

# HDFS
hdfs dfsadmin -report  # Phải thấy "Live datanodes"

# Python packages
python -c "import polars, numpy, pyspark"  # Không lỗi

# File CSV
ls -lh data/raw/HI-Large_Trans.csv  # Phải ~16GB
```

### 2. Khởi động HDFS (nếu chưa chạy)

```bash
# Start HDFS
start-dfs.sh

# Đợi 10 giây, rồi kiểm tra
hdfs dfsadmin -report
```

---

<a id="pipeline-7-buoc"></a>
## 🔄 PIPELINE 7 BƯỚC

⚠️ **LƯU Ý QUAN TRỌNG**: Pipeline đã được tối ưu từ 8 bước xuống còn **7 bước**. Bước khởi tạo centroids (bước 3 cũ) đã được **loại bỏ** vì MLlib K-means tự động sử dụng thuật toán **k-means++** thông minh để khởi tạo centroids ngay trong quá trình clustering.

### BƯỚC 1: Khám phá dữ liệu 🔍

**Mục đích**: Hiểu cấu trúc CSV, xem thống kê  
**Thời gian**: ~30 giây

```bash
cd /home/ultimatebrok/Downloads/Final
python scripts/polars/explore_fast.py
```

**Output**: In ra màn hình
- Schema (cấu trúc 11 cột)
- Sample 100K dòng
- Thống kê mô tả
- Tỷ lệ rửa tiền (~0.13%)
- Top 10 loại tiền tệ

---

### BƯỚC 2: Xử lý và trích xuất đặc trưng 🔧

**Mục đích**: Chuyển dữ liệu thô thành dạng số  
**Thời gian**: ~10 phút

```bash
python scripts/polars/prepare_polars.py
```

**Công việc**:
1. Parse timestamp → hour, day_of_week
2. Tính amount_ratio
3. Hash route (From Bank + To Bank)
4. Encode categorical (currency, payment format)
5. Normalize tất cả về [0, 1]

**Output**: `data/processed/hadoop_input_temp.txt` (33GB, TẠM THỜI)

⚠️  **LƯU Ý**: File này sẽ BỊ XÓA tự động ở bước 3!

---

### ~~BƯỚC 3: Khởi tạo tâm cụm~~ ❌ **ĐÃ LOẠI BỎ**

**Tại sao loại bỏ?**
- MLlib K-means tự động sử dụng **k-means++** (thuật toán thông minh)
- Không cần file `centroids_temp.txt` nữa
- Giảm 30 giây thời gian chạy
- Kết quả **TỐT HƠN** nhờ thuật toán k-means++ của MLlib

---

### BƯỚC 3: Upload lên HDFS ☁️

**Mục đích**: Chuyển dữ liệu lên hệ thống phân tán  
**Thời gian**: ~5 phút

```bash
./scripts/spark/setup_hdfs.sh
```

**Công việc**:
1. Kiểm tra HDFS running
2. Tạo thư mục /user/spark/hi_large/
3. Upload hadoop_input_temp.txt (33GB)
4. **🗑️  TỰ ĐỘNG XÓA temp files**
5. Verify uploads thành công

**Kết quả**:
- Dữ liệu CHỈ tồn tại trên HDFS
- KHÔNG còn file lớn ở local
- Tuân thủ quy định bảo mật ✅

**Kiểm tra**:
```bash
# Xem dữ liệu trên HDFS
hdfs dfs -ls -R /user/spark/hi_large/

# Kiểm tra kích thước
hdfs dfs -du -h /user/spark/hi_large/
```

---

### BƯỚC 4: Chạy K-means trên Spark 🚀

**Mục đích**: Phân cụm 179M giao dịch bằng MLlib K-means  
**Thời gian**: 10-25 phút (tùy phần cứng) - Nhanh hơn 30-50% nhờ MLlib!

```bash
./scripts/spark/run_spark.sh
```

**MLlib K-means với k-means++ initialization**:
```
KHỞI TẠO (TỰ ĐỘNG bởi MLlib):
  - K=5 tâm cụm
  - Sử dụng k-means++ (thông minh, không random)
  - Max iterations = 15
  - Tối ưu Catalyst + Tungsten engine

LẶP LẠI:
  1. Gán mỗi điểm vào cụm gần nhất
     (tính khoảng cách Euclidean)
  
  2. Cập nhật tâm cụm
     (trung bình tất cả điểm trong cụm)
  
  3. Kiểm tra hội tụ
     (nếu shift < threshold → dừng)

KẾT QUẢ:
  - 5 tâm cụm cuối cùng (tốt hơn random init)
  - Phân phối giao dịch trong từng cụm
  - Hội tụ nhanh hơn (~10-12 iterations thay vì 15)
```

**Quá trình hội tụ** (từ log thực tế):
```
Iteration  1: shift = 2.232  (chưa ổn định)
Iteration  5: shift = 0.383
Iteration 10: shift = 0.046
Iteration 15: shift = 0.010  (đã hội tụ ✓)
```

**Monitor**:
```bash
# Spark UI (khi đang chạy)
# Mở browser: http://localhost:4040
```

---

### BƯỚC 5: Tải kết quả về 📥

**Mục đích**: Lấy tâm cụm cuối cùng từ HDFS  
**Thời gian**: ~30 giây

```bash
./scripts/spark/download_from_hdfs.sh
```

**Output**: `data/results/final_centroids.txt` (~4KB)

**Tại sao được phép tải về?**
- File rất nhỏ (~4KB)
- Chỉ chứa kết quả tổng hợp (5 tâm cụm)
- Không phải dữ liệu gốc

---

### BƯỚC 6: Gán nhãn cụm 🏷️

**Mục đích**: Xác định mỗi giao dịch thuộc cụm nào  
**Thời gian**: ~10 phút

```bash
python scripts/polars/assign_clusters_polars.py
```

**Thuật toán**:
```python
FOR mỗi giao dịch:
    # Tính khoảng cách đến 5 tâm cụm
    distances = [dist(giao_dịch, tâm_i) for i in range(5)]
    
    # Chọn cụm gần nhất
    cluster_id = argmin(distances)
```

**Tối ưu**: Xử lý 1M giao dịch/batch thay vì từng cái

**Output**: `data/results/clustered_results.txt`

---

### BƯỚC 7: Phân tích kết quả 📊

**Mục đích**: Tìm cụm có tỷ lệ rửa tiền cao  
**Thời gian**: ~2 phút

```bash
python scripts/polars/analyze_polars.py
```

**Phân tích**:
1. Kích thước mỗi cụm
2. Tỷ lệ rửa tiền trong từng cụm
3. High-risk clusters (>10% laundering)
4. Feature averages per cluster

**Kết quả mẫu**:
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
```

---

<a id="chay-tu-dong"></a>
## 🎯 CHẠY TỰ ĐỘNG (Khuyến nghị)

Thay vì chạy từng bước, dùng script tự động:

```bash
./scripts/pipeline/full_pipeline_spark_v2.sh

### Flags quan trọng (chạy ngay từ CLI)

```bash
# KMeans
--seed N       # seed (vd 42)
--k N          # số cụm K (vd 5)
--max-iter N   # số vòng lặp tối đa (vd 15)
--tol FLOAT    # ngưỡng hội tụ (vd 1e-4)

# Điều khiển pipeline
--reset        # reset checkpoints
--from-step N  # chạy từ bước N (1-7)
--skip-step N  # bỏ qua bước N
--dry-run      # chỉ in kế hoạch

# Ví dụ
./scripts/pipeline/full_pipeline_spark_v2.sh --k 6 --max-iter 20 --seed 33 --tol 1e-5
```
```

Pipeline sẽ tự động:
- Chạy 7 bước liên tiếp
- Checkpoint (bỏ qua bước đã hoàn thành)
- Log chi tiết vào `logs/pipeline_log_*.md`
- Sử dụng MLlib K-means với k-means++ tự động

**Thời gian**: 35-50 phút (nhanh hơn 30-50% so với trước)

---

<a id="loi-thuong-gap"></a>
## 🔧 XỬ LÝ LỖI THƯỜNG GẶP

### Lỗi 1: HDFS không chạy

**Triệu chứng**:
```
Connection refused
```

**Giải pháp**:
```bash
# Khởi động lại HDFS
stop-dfs.sh
start-dfs.sh

# Đợi 10 giây, kiểm tra
hdfs dfsadmin -report
```

---

### Lỗi 2: Out of Memory

**Triệu chứng**:
```
java.lang.OutOfMemoryError: Java heap space
```

**Giải pháp**: Tăng memory trong `scripts/spark/run_spark.sh`
```bash
# Sửa dòng:
--driver-memory 8g \      # Tăng từ 4g
--executor-memory 8g \    # Tăng từ 4g
```

---

### Lỗi 3: File temp không tự động xóa

**Triệu chứng**: Vẫn thấy file trong `data/processed/`

**Giải pháp**:
```bash
# Xóa thủ công
rm -rf data/processed/*

# Hoặc dùng script cleanup
./scripts/pipeline/clean_spark.sh
```

---

<a id="xem-ket-qua"></a>
## 📊 XEM KẾT QUẢ

### Log pipeline
```bash
cat logs/pipeline_log_*.md
```

### Tâm cụm cuối cùng
```bash
cat data/results/final_centroids.txt
```

### Dữ liệu đã gán nhãn (10 dòng đầu)
```bash
head data/results/clustered_results.txt
```

---

<a id="don-dep"></a>
## 🧹 DỌN DẸP SAU KHI XONG

### Reset toàn bộ
```bash
./scripts/pipeline/clean_spark.sh
```

Xóa:
- Logs
- Temp files
- Checkpoints
- Results

### Chỉ reset checkpoints (chạy lại từ đầu)
```bash
./scripts/pipeline/reset_pipeline.sh
```

---

## 💡 MẸO & GỢI Ý

### 1. Tăng tốc độ
- Tăng RAM: Sửa `--executor-memory` trong `run_spark.sh`
- Tăng CPU cores: Sửa `TOTAL_CORES` trong `run_spark.sh`

### 2. Debug từng bước
Nếu pipeline lỗi, chạy từng bước riêng để tìm lỗi:
```bash
python scripts/polars/explore_fast.py
python scripts/polars/prepare_polars.py
# ... và tiếp tục
```

### 3. Test với sample nhỏ
Để test nhanh, dùng sample nhỏ:
```bash
# Tạo sample 100K dòng
head -n 100000 data/raw/HI-Large_Trans.csv > data/raw/sample.csv

# Sửa DATA_RAW trong scripts để dùng sample.csv
# Rồi chạy pipeline
```

### 4. Theo dõi tiến trình
```bash
# Terminal 1: Chạy pipeline
./scripts/pipeline/full_pipeline_spark.sh

# Terminal 2: Theo dõi log real-time
tail -f logs/pipeline_log_*.md
```

---

<a id="checklist"></a>
## ✅ CHECKLIST TRƯỚC KHI CHẠY

- [ ] Java installed (version 11 hoặc 17)
- [ ] HDFS đang chạy (`hdfs dfsadmin -report`)
- [ ] Spark installed (`spark-submit --version`)
- [ ] Python packages installed (`polars`, `numpy`, `pyspark`)
- [ ] File CSV tồn tại (`data/raw/HI-Large_Trans.csv`)
- [ ] Disk space đủ (>50GB trống)
- [ ] RAM đủ (>16GB, khuyến nghị 32GB)

---

<a id="tai-lieu"></a>
## 📚 TÀI LIỆU THAM KHẢO

- **BAO_CAO_TIEU_LUAN.md**: Báo cáo chi tiết bằng tiếng Việt
- **README.md**: Quick start guide
- **docs/PROJECT_OVERVIEW.md**: Kiến trúc hệ thống
- **CHANGELOG.md**: Lịch sử thay đổi

---

## 🆘 CẦN TRỢ GIÚP?

1. Xem log: `logs/pipeline_log_*.md`
2. Xem troubleshooting trong `BAO_CAO_TIEU_LUAN.md`
3. Check HDFS: `hdfs dfsadmin -report`
4. Check Spark UI: `http://localhost:4040`

---

**Chúc bạn chạy thành công! 🎉**
