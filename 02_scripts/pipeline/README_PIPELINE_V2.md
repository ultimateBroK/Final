# 🚀 Pipeline V2.0 - Siêu Việt Edition

## Tổng Quan

Pipeline V2.0 là phiên bản nâng cấp siêu việt của `full_pipeline_spark.sh` với nhiều tính năng mới mạnh mẽ, linh hoạt và thân thiện với người dùng.

## So Sánh V1 vs V2

| Tính năng | V1 (full_pipeline_spark.sh) | V2 (full_pipeline_spark_v2.sh) |
|-----------|------------------------------|--------------------------------|
| Command line arguments | ❌ Không | ✅ Có (--reset, --from-step, --skip-step, --dry-run, --seed, --k, --max-iter, --tol) |
| Prerequisites checking | ❌ Không | ✅ Kiểm tra Python, HDFS, CSV, RAM, Disk |
| Progress bar | ❌ Không | ✅ Visual progress [████████░░] 6/8 (75%) |
| Step descriptions | ⚠️ Cơ bản | ✅ Chi tiết với mục đích và thời gian |
| Next steps suggestions | ❌ Không | ✅ 6 gợi ý chi tiết với code examples |
| Research suggestions | ❌ Không | ✅ 6 hướng nghiên cứu tiếp |
| Error handling | ⚠️ Cơ bản | ✅ Set -euo pipefail, detailed errors |
| Statistics | ⚠️ Cơ bản | ✅ Thống kê transactions, clusters, log size |
| Help menu | ❌ Không | ✅ Đầy đủ với examples |
| Dry-run mode | ❌ Không | ✅ Preview execution plan |

## Tính Năng Mới Trong V2.0

### 1️⃣ Command Line Arguments

```bash
# Chạy bình thường
./02_scripts/pipeline/full_pipeline_spark_v2.sh

# Reset checkpoints và chạy lại từ đầu
./02_scripts/pipeline/full_pipeline_spark_v2.sh --reset

# Chạy từ bước 5 (Spark)
./02_scripts/pipeline/full_pipeline_spark_v2.sh --from-step 5

# Bỏ qua bước 1 (đã explore rồi)
./02_scripts/pipeline/full_pipeline_spark_v2.sh --skip-step 1

# Xem trước kế hoạch không chạy thật
./02_scripts/pipeline/full_pipeline_spark_v2.sh --dry-run

# Xem hướng dẫn đầy đủ
./02_scripts/pipeline/full_pipeline_spark_v2.sh --help

# Chạy với tham số KMeans
#   --seed N       : đặt seed (vd 42)
#   --k N          : số cụm K (vd 5)
#   --max-iter N   : số vòng lặp tối đa (vd 15)
#   --tol FLOAT    : ngưỡng hội tụ (vd 1e-4)

# Ví dụ: K=6, maxIter=25, seed=33, tol=1e-5
./02_scripts/pipeline/full_pipeline_spark_v2.sh --k 6 --max-iter 25 --seed 33 --tol 1e-5

# Batch nhiều seed cho báo cáo
for s in 11 22 33 44 55; do \
  ./02_scripts/pipeline/clean_all.sh; \
  ./02_scripts/pipeline/full_pipeline_spark_v2.sh --seed $s --k 5 --max-iter 15 --tol 1e-4; \
  python 02_scripts/data/snapshot_results.py; \
done
```

### 2️⃣ Prerequisites Checking

Tự động kiểm tra:
- ✅ Python version
- ✅ HDFS availability
- ✅ CSV file existence và size
- ✅ RAM khả dụng (cảnh báo nếu < 8GB)
- ✅ Disk space khả dụng

### 3️⃣ Visual Progress Bar

```
Tiến độ: [████████████████░░░░] 6/8 (75%)
```

### 4️⃣ Detailed Step Information

Mỗi bước có:
- 🎯 Mục đích rõ ràng
- ⏱️ Thời gian ước tính
- 🛠️ Status realtime
- ✅ Thời gian hoàn thành thực tế

### 5️⃣ Next Steps Suggestions

Sau khi chạy xong, gợi ý 6 bước tiếp theo:
1. Tạo snapshot kết quả
2. Trực quan hóa với Jupyter
3. Kiểm tra HDFS
4. Đọc báo cáo chi tiết
5. Chạy lại với tham số khác
6. Tối ưu và thử nghiệm

### 6️⃣ Research Directions

Gợi ý 6 hướng nghiên cứu:
1. Model comparison (DBSCAN, Isolation Forest)
2. Supervised learning (RF, XGBoost)
3. Advanced feature engineering
4. Real-time streaming (Kafka)
5. Deployment (Docker, K8s)
6. Monitoring (Prometheus, Grafana)

### 7️⃣ Better Error Handling

- `set -euo pipefail` cho strict mode
- Detailed error messages
- Exit codes hợp lý
- Checkpoint system robust hơn

### 8️⃣ Rich Logging

Log file có:
- Markdown formatting đẹp
- Statistics tables
- Code examples
- Links và references

## Khi Nào Dùng V1, Khi Nào Dùng V2?

### Dùng V1 khi:
- ✅ Muốn script đơn giản, ít dependencies
- ✅ Chạy trong automation/CI/CD
- ✅ Không cần interactive features
- ✅ Production environment

### Dùng V2 khi:
- ✅ Development và testing
- ✅ Learning và exploring
- ✅ Cần flexibility (skip steps, from-step)
- ✅ Muốn detailed feedback
- ✅ Debug và troubleshooting

## Migration từ V1 sang V2

V2 **hoàn toàn tương thích** với V1:

```bash
# V1
./02_scripts/pipeline/full_pipeline_spark.sh

# V2 (tương đương)
./02_scripts/pipeline/full_pipeline_spark_v2.sh
```

Không cần thay đổi gì trong code hoặc data!

## Examples

### Use Case 1: First Time Run

```bash
# Xem trước kế hoạch
./02_scripts/pipeline/full_pipeline_spark_v2.sh --dry-run

# Chạy thật
./02_scripts/pipeline/full_pipeline_spark_v2.sh
```

### Use Case 2: Resume After Failure

```bash
# Nếu bị lỗi ở bước 5 (Spark), fix lỗi rồi:
./02_scripts/pipeline/full_pipeline_spark_v2.sh --from-step 5
```

### Use Case 3: Quick Iteration

```bash
# Đã có dữ liệu explore, bỏ qua bước 1
./02_scripts/pipeline/full_pipeline_spark_v2.sh --skip-step 1

# Hoặc chỉ test Spark part
./02_scripts/pipeline/full_pipeline_spark_v2.sh --from-step 4
```

### Use Case 4: Complete Reset

```bash
# Xóa tất cả checkpoints, chạy lại từ đầu
./02_scripts/pipeline/full_pipeline_spark_v2.sh --reset
```

## Troubleshooting

### Lỗi: "Python không tìm thấy"

```bash
# Activate virtual environment
source .venv/bin/activate

# Chạy lại
./02_scripts/pipeline/full_pipeline_spark_v2.sh
```

### Lỗi: "HDFS không khởi động"

```bash
# Start HDFS
start-dfs.sh

# Verify
hdfs dfsadmin -report

# Chạy lại từ bước 4
./02_scripts/pipeline/full_pipeline_spark_v2.sh --from-step 4
```

### Lỗi: "RAM không đủ"

V2 sẽ cảnh báo nhưng vẫn tiếp tục. Nếu OOM:
- Close các ứng dụng khác
- Tăng swap space
- Hoặc dùng machine có RAM lớn hơn

## Performance

V2 có overhead nhỏ (~1-2s) do:
- Prerequisites checking
- Progress tracking

Nhưng không ảnh hưởng total time vì phần lớn thời gian là processing.

## Snapshots

Sau khi chạy xong, bạn có thể tạo snapshot kết quả và xem lại sau:

```bash
# Tạo snapshot kết quả hiện tại
python 02_scripts/data/snapshot_results.py

# Liệt kê các snapshot
python 02_scripts/data/snapshot_results.py --list
```

Snapshot gần nhất trong project:
- `05_snapshots/snapshot_20251029_213229/` (342.75 MB, 2025-10-29 21:32:30)
- Gồm: `final_centroids.txt`, `clustered_results.txt`, `suspicious_transactions.csv`, `pipeline_log.md`

## Future Enhancements

Có thể thêm trong tương lai:
- [ ] `--parallel` mode cho multi-dataset
- [ ] `--profile` mode cho performance profiling
- [ ] `--notify` để gửi notification khi xong
- [ ] `--config` file support
- [ ] Web UI cho monitoring

## Feedback

Nếu có ý kiến hoặc bug, mở issue hoặc contact team!

---

**Version:** 2.0  
**Ngày:** 2025-10-29  
**Tác giả:** Dự Án Phân Tích Rửa Tiền
