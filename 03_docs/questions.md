# 📝 CÂU HỎI KIỂM TRA - DỰ ÁN PHÁT HIỆN RỬA TIỀN

**Giáo viên tra hỏi sinh viên về khả năng hiểu biết dự án**

---

## 📚 PHẦN 1: TỔNG QUAN DỰ ÁN (20%)

### Câu 1: Mô tả bài toán
**Câu hỏi:** Em hãy giải thích vấn đề mà dự án này giải quyết là gì? Tại sao cần sử dụng Big Data?

**Câu trả lời:**
Dự án giải quyết bài toán phát hiện giao dịch rửa tiền trong một tập dữ liệu khổng lồ gồm 179,702,229 giao dịch (16GB CSV). Vấn đề chính là:
- **Khối lượng dữ liệu quá lớn**: 179 triệu giao dịch không thể xử lý bằng máy tính thường
- **Cần tốc độ**: Phải phân tích nhanh để phát hiện kịp thời các giao dịch nghi ngờ
- **Độ chính xác cao**: Giảm thiểu false positive (cảnh báo giả)
- **Tuân thủ bảo mật**: Dữ liệu khách hàng nhạy cảm, không được lưu cục bộ

Cần Big Data vì:
- Dữ liệu vượt quá khả năng xử lý của một máy đơn lẻ
- Yêu cầu xử lý phân tán trên nhiều máy tính để tăng tốc độ
- Thuật toán K-means cần lặp nhiều lần trên toàn bộ dataset

---

### Câu 2: Kết quả đạt được
**Câu hỏi:** Dự án đã đạt được những kết quả gì? Nêu cụ thể các chỉ số.

**Câu trả lời:**
Kết quả chính:
- ✅ **Xử lý thành công**: 179,702,229 giao dịch (100% dữ liệu)
- ✅ **Thời gian**: 11 phút 47 giây (707 giây) - rất nhanh cho khối lượng này
- ✅ **Phân cụm**: Chia thành 5 nhóm với phân phối rõ ràng:
  - Cluster 0: 36,926,395 giao dịch (20.55%) - Tỷ lệ rửa tiền: 0.081%
  - Cluster 1: 69,939,082 giao dịch (38.92%) - Tỷ lệ rửa tiền: 0.113%
  - Cluster 2: 68,931,713 giao dịch (38.36%) - Tỷ lệ rửa tiền: 0.167%
  - Cluster 3: 18 giao dịch (0.00%) - Tỷ lệ rửa tiền: 5.556% (outlier)
  - Cluster 4: 3,905,021 giao dịch (2.17%) - Tỷ lệ rửa tiền: 0.041%
- ✅ **Phát hiện**: 225,546 giao dịch nghi ngờ cần kiểm tra thủ công
- ✅ **Tuân thủ**: Không lưu dữ liệu lớn ở local (chỉ trên HDFS)

---

### Câu 3: Mục tiêu dự án
**Câu hỏi:** Em liệt kê 4 mục tiêu chính của dự án này?

**Câu trả lời:**
1. **Phân tích dữ liệu giao dịch quy mô lớn**: Xử lý 179 triệu giao dịch, trích xuất và chuẩn hóa đặc trưng
2. **Phân cụm bằng K-means**: Tự động chia giao dịch thành 5 nhóm sử dụng Apache Spark
3. **Phát hiện giao dịch nghi ngờ**: Xác định các cụm có tỷ lệ rửa tiền cao bất thường
4. **Tuân thủ quy định bảo mật**: Không lưu dữ liệu lớn ở máy cục bộ, chỉ trên HDFS

---

## 💻 PHẦN 2: CÔNG NGHỆ SỬ DỤNG (30%)

### Câu 4: Apache Spark
**Câu hỏi:** Apache Spark là gì? Tại sao dùng Spark thay vì Hadoop MapReduce?

**Câu trả lời:**
**Apache Spark** là framework xử lý Big Data phân tán, cho phép nhiều máy tính làm việc song song.

**So sánh Hadoop vs Spark:**
| Tiêu chí | Hadoop MapReduce | Apache Spark |
|----------|------------------|--------------|
| Tốc độ | Chậm (đọc/ghi disk) | Nhanh hơn 10-100x (in-memory) |
| Processing | Disk-based | In-memory |
| Code | Dài, phức tạp (mapper/reducer) | Ngắn gọn (PySpark API) |
| Phù hợp | Batch processing lớn | Iterative algorithms (như K-means) |

**Lý do chọn Spark:**
- K-means cần lặp nhiều lần (15 iterations), Spark cache dữ liệu trong RAM → nhanh hơn
- PySpark API dễ học, dễ maintain hơn Hadoop MapReduce
- MLlib có sẵn K-means với k-means++ initialization
- Catalyst + Tungsten tự động tối ưu hóa

---

### Câu 5: Polars
**Câu hỏi:** Polars là gì? Tại sao dùng Polars thay vì Pandas?

**Câu trả lời:**
**Polars** là thư viện DataFrame xử lý dữ liệu cực nhanh, viết bằng Rust.

**So sánh Pandas vs Polars:**
| Tiêu chí | Pandas | Polars |
|----------|--------|--------|
| Tốc độ đọc 16GB CSV | ~45 phút | ~4-5 phút (nhanh gấp 9 lần) |
| Ngôn ngữ nền | Python | Rust (nhanh như C++) |
| Lazy evaluation | Không | Có (chỉ tính khi cần) |
| Memory | Load toàn bộ vào RAM | Streaming, xử lý file lớn hơn RAM |

**Lý do chọn Polars:**
- Đọc 16GB CSV trong ~5 phút (Pandas mất 45 phút)
- Lazy evaluation giúp tối ưu query
- Streaming mode xử lý file lớn không cần load hết vào RAM
- API tương tự Pandas, dễ học

---

### Câu 6: HDFS
**Câu hỏi:** HDFS là gì? Giải thích cơ chế hoạt động và lợi ích.

**Câu trả lời:**
**HDFS (Hadoop Distributed File System)** là hệ thống lưu trữ file phân tán, lưu file lớn trên nhiều máy tính.

**Cách hoạt động:**
1. **Chia nhỏ**: File 33GB được chia thành các block 128MB
2. **Sao lưu (Replication)**: Mỗi block được lưu ở 3 máy khác nhau (default replication factor = 3)
3. **Fault-tolerant**: Nếu 1 máy hỏng → vẫn còn 2 bản sao ở máy khác

**Lợi ích:**
- ✅ Không giới hạn dung lượng (thêm máy = thêm không gian)
- ✅ An toàn (tự động sao lưu 3 bản)
- ✅ Tuân thủ quy định (không lưu dữ liệu nhạy cảm ở local)
- ✅ Hỗ trợ xử lý phân tán (Spark đọc trực tiếp từ HDFS)

**Cấu trúc HDFS trong dự án:**
```
/user/spark/hi_large/
├── input/
│   └── hadoop_input.txt       (31GB - dữ liệu đã xử lý)
└── output_centroids/          (4KB - kết quả K-means)
    └── part-00000
```

---

### Câu 7: K-means Algorithm
**Câu hỏi:** K-means là gì? Giải thích thuật toán k-means++ (k-means||)?

**Câu trả lời:**
**K-means** là thuật toán phân cụm unsupervised learning, tự động chia dữ liệu thành K nhóm.

**Quy trình K-means cơ bản:**
1. **Khởi tạo**: Chọn K tâm cụm ban đầu (centroids)
2. **Assign**: Gán mỗi điểm vào cụm gần nhất (theo khoảng cách Euclidean)
3. **Update**: Tính lại tâm cụm mới (trung bình của các điểm trong cụm)
4. **Lặp lại**: Bước 2-3 cho đến khi hội tụ (tâm cụm không thay đổi nhiều)

**K-means++ (k-means||):**
- **Vấn đề**: Random initialization có thể cho kết quả kém
- **Giải pháp**: Chọn tâm cụm thông minh hơn:
  1. Tâm 1: Chọn ngẫu nhiên
  2. Tâm 2: Chọn điểm xa tâm 1 nhất
  3. Tâm 3: Chọn điểm xa 2 tâm trước nhất
  4. ... (lặp lại cho K tâm)
- **Lợi ích**: 
  - Hội tụ nhanh hơn (10-12 iterations thay vì 15-20)
  - Kết quả ổn định hơn, tránh local minima
  - Trong dự án: MLlib tự động dùng k-means++ (không cần code thủ công)

**Cấu hình trong dự án:**
- K = 5 (5 cụm)
- MaxIter = 15 (tối đa 15 vòng lặp)
- Seed = 42 (để tái tạo kết quả)
- Tol = 1e-4 (ngưỡng hội tụ)

---

### Câu 8: PySpark MLlib
**Câu hỏi:** MLlib là gì? So sánh MLlib K-means với implementation thủ công?

**Câu trả lời:**
**MLlib** là thư viện Machine Learning của Apache Spark, hỗ trợ các thuật toán ML trên Big Data.

**So sánh:**
| Tiêu chí | MLlib K-means | Implementation thủ công (RDD) |
|----------|---------------|-------------------------------|
| Tốc độ | Nhanh (Catalyst + Tungsten) | Chậm hơn 30-50% |
| Code | Đơn giản (vài dòng) | Phức tạp (hàng trăm dòng) |
| Khởi tạo | k-means++ tự động | Phải code thủ công |
| Tối ưu | Catalyst optimizer | Không có |
| Maintain | Dễ | Khó (phải tự debug) |

**Lợi ích MLlib trong dự án:**
- ✅ **Catalyst Optimizer**: Tự động sắp xếp lại query để nhanh nhất
- ✅ **Tungsten Execution**: Thực thi nhanh trong RAM (code generation)
- ✅ **k-means++**: Tự động khởi tạo centroids thông minh
- ✅ **Adaptive Query Execution (AQE)**: Tự động điều chỉnh số phần chia

**Thời gian:**
- MLlib: 6 phút 5 giây (365s)
- RDD-based: Ước tính 10-15 phút (chậm hơn 30-50%)

---

## 🔧 PHẦN 3: WORKFLOW & CODE (30%)

### Câu 9: Pipeline 7 bước
**Câu hỏi:** Liệt kê và giải thích 7 bước trong pipeline. Mỗi bước làm gì?

**Câu trả lời:**

**Pipeline 7 bước (Thời gian thực tế: 11 phút 22 giây):**

1. **Bước 1: Khám phá dữ liệu (13s)**
   - Script: `explore_fast.py`
   - Công việc: Đọc 100K dòng đầu, thống kê mô tả, phân tích phân phối
   - Output: In ra terminal (không tạo file)

2. **Bước 2: Feature Engineering (36s)**
   - Script: `prepare_polars.py`
   - Công việc:
     - Parse timestamp → hour, day_of_week
     - Tính amount_ratio = received / paid
     - Mã hóa categorical (currency, payment_format)
     - Chuẩn hóa Z-score
   - Output: `hadoop_input_temp.txt` (31GB, TẠM THỜI)

3. **Bước 3: Upload HDFS (41s)**
   - Script: `setup_hdfs.sh`
   - Công việc:
     - Upload file temp lên HDFS
     - **Tự động xóa file temp** (tuân thủ bảo mật)
   - Output: `/user/spark/hi_large/input/hadoop_input.txt` trên HDFS

4. **Bước 4: K-means MLlib (6 phút 5s)**
   - Script: `run_spark.sh` + `kmeans_spark.py`
   - Công việc:
     - Đọc dữ liệu từ HDFS
     - Tạo vector đặc trưng
     - Chạy K-means với k-means++ (15 iterations)
     - Lưu 5 centroids lên HDFS
   - Output: `/user/spark/hi_large/output_centroids/` trên HDFS

5. **Bước 5: Download kết quả (3s)**
   - Script: `download_from_hdfs.sh`
   - Công việc: Tải 5 centroids về local (chỉ 4KB)
   - Output: `final_centroids.txt`

6. **Bước 6: Gán nhãn cụm (3 phút 14s)**
   - Script: `assign_clusters.py`
   - Công việc:
     - Đọc streaming từ HDFS
     - Tính khoảng cách Euclidean đến 5 centroids
     - Gán mỗi giao dịch vào cụm gần nhất
   - Output: `clustered_results.txt` (342.75 MB)

7. **Bước 7: Phân tích (30s)**
   - Script: `analyze.py`
   - Công việc:
     - Gắn cluster_id vào dữ liệu gốc
     - Tính tỷ lệ rửa tiền mỗi cụm
     - Xuất báo cáo
   - Output: Báo cáo in ra terminal

---

### Câu 10: Feature Engineering
**Câu hỏi:** Giải thích chi tiết các đặc trưng được trích xuất trong bước 2?

**Câu trả lời:**

**9 đặc trưng được tạo ra:**

1. **amount_received** (Số tiền nhận)
   - Giá trị gốc từ CSV
   - Chuẩn hóa Z-score: `(x - mean) / std`

2. **amount_paid** (Số tiền trả)
   - Giá trị gốc từ CSV
   - Chuẩn hóa Z-score

3. **amount_ratio** (Tỷ lệ)
   - Công thức: `amount_received / amount_paid`
   - Lý do: Phát hiện bất thường (vd: nhận 1M, trả 100$ → ratio = 10,000 → nghi ngờ)

4. **hour** (Giờ trong ngày)
   - Parse từ Timestamp: "2022/08/01 00:17" → 0
   - Lý do: Giao dịch rửa tiền thường vào giờ lạ (2-3h sáng)

5. **day_of_week** (Ngày trong tuần)
   - Parse từ Timestamp: 0 = Chủ Nhật, 6 = Thứ Bảy
   - Lý do: Giao dịch rửa tiền thường vào cuối tuần

6. **route_hash** (Mã tuyến)
   - Công thức: `hash(From Bank + To Bank)`
   - Lý do: Nếu tuyến A→B xuất hiện quá nhiều → nghi ngờ

7. **recv_curr_encoded** (Loại tiền nhận)
   - Label Encoding: "US Dollar" → 0, "Euro" → 1, "Bitcoin" → 2, ...
   - Lý do: Máy tính chỉ hiểu số

8. **payment_curr_encoded** (Loại tiền trả)
   - Label Encoding tương tự

9. **payment_format_encoded** (Hình thức thanh toán)
   - Label Encoding: "Reinvestment" → 0, "Cheque" → 1, ...

**Chuẩn hóa Z-score:**
- Công thức: `(x - mean) / std`
- Mục đích: Đưa tất cả features về cùng scale (mean=0, std=1)
- Lý do: Tránh features có giá trị lớn (vd: amount) lấn át features nhỏ (vd: hour)

---

### Câu 11: Code Spark
**Câu hỏi:** Giải thích đoạn code sau trong `kmeans_spark.py`:

```python
kmeans = KMeans() \
    .setK(k) \
    .setMaxIter(max_iter) \
    .setInitMode("k-means||") \
    .setFeaturesCol("features") \
    .setPredictionCol("cluster") \
    .setSeed(seed) \
    .setTol(tol)
```

**Câu trả lời:**

Đoạn code này cấu hình thuật toán K-means trong Spark MLlib:

- **`setK(k)`**: Số cụm K = 5 (chia thành 5 nhóm)
- **`setMaxIter(max_iter)`**: Số lần lặp tối đa = 15 (nếu chưa hội tụ sau 15 lần → dừng)
- **`setInitMode("k-means||")`**: Khởi tạo k-means++ (chọn centroids thông minh, không phải random)
- **`setFeaturesCol("features")`**: Cột chứa vector đặc trưng (9 features đã normalize)
- **`setPredictionCol("cluster")`**: Tên cột output chứa cluster_id (0-4)
- **`setSeed(seed)`**: Seed = 42 (để kết quả có thể tái tạo giống nhau mỗi lần chạy)
- **`setTol(tol)`**: Ngưỡng hội tụ = 1e-4 (nếu tâm cụm thay đổi < 0.0001 → dừng sớm)

**Builder pattern**: Dùng chuỗi `.setXXX()` để cấu hình từng tham số, dễ đọc và maintain.

---

### Câu 12: Xử lý file lớn
**Câu hỏi:** Làm sao Polars xử lý file 16GB mà không tràn RAM (máy chỉ có 16GB)?

**Câu trả lời:**

**3 kỹ thuật chính:**

1. **Lazy Evaluation (Đọc trì hoãn)**
   ```python
   df = pl.scan_csv('file.csv')  # Không load hết vào RAM
   df = df.filter(...)            # Chỉ lập kế hoạch, chưa thực thi
   df.sink_csv('output.csv')      # Mới thực thi + streaming
   ```
   - `scan_csv()`: Chỉ đọc metadata, không load dữ liệu
   - `sink_csv()`: Streaming ra file, không giữ trong RAM

2. **Streaming Processing**
   ```python
   df.sink_csv('output.csv', maintain_order=False)
   ```
   - Đọc từng chunk (vd: 100MB), xử lý, ghi ra file
   - Xóa chunk khỏi RAM sau khi ghi xong
   - Giống như streaming video (không tải hết về)

3. **Columnar Format (Apache Arrow)**
   - Polars dùng Apache Arrow (columnar storage)
   - Chỉ load cột cần thiết vào RAM (không phải load cả row)
   - Ví dụ: Chỉ cần cột "Amount" → chỉ load cột đó (tiết kiệm RAM)

**Trong dự án:**
- Bước 1: `scan_csv()` đọc lazy
- Bước 2: `sink_csv()` streaming ghi ra file 31GB
- Bước 6: Đọc streaming từ HDFS bằng batch 1 triệu dòng

---

### Câu 13: NumPy Vectorization
**Câu hỏi:** Giải thích đoạn code sau trong `04_assign_clusters.py`:

```python
distances = np.linalg.norm(batch - centroids[:, np.newaxis], axis=2)
cluster_ids = np.argmin(distances, axis=0)
```

**Câu trả lời:**

**Mục đích:** Tính khoảng cách từ 1 triệu giao dịch đến 5 centroids, tìm cụm gần nhất.

**Giải thích từng dòng:**

1. **`batch`**: Mảng NumPy shape (1,000,000, 9) - 1 triệu giao dịch, mỗi giao dịch 9 features
2. **`centroids`**: Mảng NumPy shape (5, 9) - 5 centroids, mỗi centroid 9 features
3. **`centroids[:, np.newaxis]`**: Thêm 1 chiều → shape (5, 1, 9)
4. **`batch - centroids[:, np.newaxis]`**: Broadcasting → shape (5, 1,000,000, 9)
   - Trừ từng giao dịch cho từng centroid
5. **`np.linalg.norm(..., axis=2)`**: Tính khoảng cách Euclidean → shape (5, 1,000,000)
   - Mỗi phần tử = khoảng cách từ 1 giao dịch đến 1 centroid
6. **`np.argmin(distances, axis=0)`**: Tìm index cụm có khoảng cách nhỏ nhất → shape (1,000,000,)
   - Mỗi phần tử = cluster_id (0-4) của giao dịch đó

**Tại sao nhanh?**
- **Vectorization**: NumPy tính toán hàng loạt (không phải vòng lặp Python)
- **C backend**: NumPy viết bằng C, nhanh gấp 100-1000 lần Python
- **Ví dụ**: Vòng lặp Python mất 10 phút, NumPy vectorization mất 6 giây

---

## 🗂️ PHẦN 4: DỮ LIỆU & KẾT QUẢ (20%)

### Câu 14: Thống kê dữ liệu
**Câu hỏi:** Mô tả tập dữ liệu HI-Large_Trans.csv: số bản ghi, kích thước, các cột?

**Câu trả lời:**

**Thông tin cơ bản:**
- **File**: HI-Large_Trans.csv
- **Kích thước**: 16 GB
- **Số bản ghi**: 179,702,229 giao dịch
- **Nguồn**: Dữ liệu mô phỏng giao dịch ngân hàng quốc tế

**11 cột:**
1. **Timestamp**: Thời gian giao dịch (chuỗi, vd: "2022/08/01 00:17")
2. **From Bank**: Mã ngân hàng gửi (số nguyên)
3. **Account**: Mã tài khoản gửi (chuỗi)
4. **To Bank**: Mã ngân hàng nhận (số nguyên)
5. **Account.1**: Mã tài khoản nhận (chuỗi)
6. **Amount Received**: Số tiền nhận (float)
7. **Receiving Currency**: Loại tiền nhận (chuỗi, vd: "US Dollar", "Euro")
8. **Amount Paid**: Số tiền trả (float)
9. **Payment Currency**: Loại tiền trả (chuỗi)
10. **Payment Format**: Hình thức thanh toán (chuỗi, vd: "Reinvestment", "Cheque")
11. **Is Laundering**: Nhãn rửa tiền (0 = bình thường, 1 = rửa tiền)

**Thống kê:**
- Tỷ lệ rửa tiền tổng thể: 0.126% (225,546 / 179,702,229)
- Top loại tiền:
  - US Dollar: 36.4%
  - Euro: 23.0%
  - Yuan: 7.2%
- Giá trị giao dịch trung bình: ~1.14 triệu đơn vị

---

### Câu 15: Phân tích kết quả
**Câu hỏi:** Cụm nào nghi ngờ rửa tiền nhất? Tại sao? Em sẽ xử lý như thế nào?

**Câu trả lời:**

**Cụm nghi ngờ nhất: Cluster 3**

**Thống kê:**
- Số giao dịch: 18 (0.00% tổng)
- Tỷ lệ rửa tiền: 5.556% (1/18 giao dịch)
- Giá trị trung bình received: 4.24 nghìn tỷ (cực lớn!)
- Giá trị trung bình paid: 2.86 nghìn tỷ
- Tỷ lệ received/paid: 21.54 (bất thường!)

**Tại sao nghi ngờ?**
1. **Tỷ lệ rửa tiền cao**: 5.556% (cao nhất trong tất cả cụm, gấp 44 lần trung bình 0.126%)
2. **Giá trị outlier**: Nghìn tỷ đơn vị (gấp hàng triệu lần giá trị trung bình)
3. **Tỷ lệ amount_ratio bất thường**: 21.54 (nhận được gấp 21 lần số tiền trả → nghi ngờ!)
4. **Số lượng ít**: Chỉ 18 giao dịch nhưng chiếm tỷ trọng giá trị rất lớn

**Xử lý:**
1. ✅ **Kiểm tra thủ công ngay lập tức** 18 giao dịch này
2. ✅ **Báo cáo cơ quan chức năng** nếu xác nhận rửa tiền
3. ✅ **Freeze tài khoản** tạm thời để điều tra
4. ✅ **Phân tích sâu**: Xem ai chuyển cho ai, tuyến nào, thời gian nào

**Cluster 2 (cảnh báo thứ hai):**
- Tỷ lệ: 0.167% (thấp hơn Cluster 3 nhưng cao nhất trong các cụm chính)
- Số giao dịch: 68,931,713 (38.36% tổng)
- Cần theo dõi thường xuyên

---

### Câu 16: WSSSE
**Câu hỏi:** WSSSE là gì? Giá trị WSSSE trong dự án là bao nhiêu? Đánh giá chất lượng?

**Câu trả lời:**

**WSSSE (Within-Set Sum of Squared Errors):**
- Tổng bình phương khoảng cách từ mỗi điểm đến tâm cụm của nó
- Công thức: `Σ(distance(point, centroid)^2)` với tất cả điểm
- **Chất lượng**: WSSSE càng nhỏ → các điểm càng gần tâm cụm → phân cụm tốt

**Trong dự án:**
- WSSSE = 961,278,012.73
- Số điểm = 179,702,229
- WSSSE trung bình/điểm = 961,278,012.73 / 179,702,229 ≈ **5.35**

**Đánh giá:**
- ✅ **Tốt**: WSSSE/điểm = 5.35 (tương đối nhỏ sau khi chuẩn hóa Z-score)
- ✅ **Phân cụm rõ ràng**: 5 cụm có phân phối đặc trưng khác biệt
- ✅ **Outlier detected**: Cluster 3 tách biệt hoàn toàn (chỉ 18 điểm)
- ⚠️ **Có thể cải thiện**: Thử K khác (3, 7, 10) để so sánh

**Cách cải thiện:**
- Dùng Elbow Method để chọn K tối ưu
- Dùng Silhouette Score để đánh giá chất lượng
- Xử lý outliers trước khi clustering (vd: loại bỏ Cluster 3)

---

## 🔒 PHẦN 5: BẢO MẬT & QUY ĐỊNH (10%)

### Câu 17: Tuân thủ quy định
**Câu hỏi:** Dự án tuân thủ quy định "không lưu dữ liệu lớn ở local" như thế nào?

**Câu trả lời:**

**Quy định:** Sinh viên không được lưu dữ liệu lớn (>1GB) ở máy cục bộ, chỉ trên HDFS.

**Workflow tuân thủ:**

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│ Raw CSV     │ ───> │ Temp Files   │ ───> │ HDFS        │
│ (01_data/   │      │ (tạm thời)   │      │ (permanent) │
│  raw/)      │      │              │      │             │
└─────────────┘      └──────────────┘      └─────────────┘
                            │                      
                            │ (auto delete)        
                            ▼                      
                      [Xóa ngay sau            
                       khi upload]              
```

**Các bước tuân thủ:**

1. **Bước 2**: Polars tạo file temp `hadoop_input_temp.txt` (31GB) ở local
2. **Bước 3**: `setup_hdfs.sh` upload lên HDFS
3. **Bước 3**: **Tự động xóa file temp** ngay sau upload:
   ```bash
   rm -rf "$PROJECT_ROOT/01_data/processed/"*
   ```
4. **Xác minh**: Kiểm tra sau khi upload
   ```bash
   du -sh 01_data/processed/  # → 0 (đã xóa!)
   hdfs dfs -du -h /user/spark/hi_large/  # → 31GB (trên HDFS)
   ```

**Files ĐƯỢC PHÉP lưu local:**
- ✅ `HI-Large_Trans.csv` (16GB) - File gốc từ giảng viên
- ✅ `final_centroids.txt` (4KB) - Kết quả tổng hợp
- ✅ `clustered_results.txt` (342MB) - Có thể tạo lại từ HDFS

**Files KHÔNG ĐƯỢC lưu local:**
- ❌ `hadoop_input_temp.txt` (31GB) - **Tự động xóa sau upload**
- ❌ Bất kỳ file trung gian nào >1GB

---

### Câu 18: Khôi phục dữ liệu
**Câu hỏi:** Nếu cần xem lại dữ liệu đã xử lý (31GB), làm thế nào?

**Câu trả lời:**

**Quy trình khôi phục từ HDFS:**

```bash
# 1. Tải về từ HDFS (tạm thời)
hdfs dfs -get /user/spark/hi_large/input/hadoop_input.txt 01_data/processed/

# 2. Sử dụng (vd: debug, phân tích)
python 02_scripts/polars/assign_clusters.py

# 3. XÓA lại sau khi dùng xong (tuân thủ quy định)
rm 01_data/processed/hadoop_input.txt
```

**Lưu ý:**
- ⚠️ CHỈ tải về khi thực sự cần thiết (debug, phân tích sâu)
- ⚠️ PHẢI xóa ngay sau khi dùng xong
- ✅ Dữ liệu vĩnh viễn chỉ tồn tại trên HDFS

**Cách tốt hơn:**
- Xử lý trực tiếp trên HDFS bằng Spark (không cần tải về)
- Chỉ tải về kết quả nhỏ (<100MB) để phân tích

---

## 🛠️ PHẦN 6: TOOLS & SCRIPTS (10%)

### Câu 19: Shell scripts
**Câu hỏi:** Giải thích workflow của `full_pipeline_spark.sh`? Checkpoint là gì?

**Câu trả lời:**

**Workflow của `full_pipeline_spark.sh`:**

1. **Khởi tạo**: Tạo file log với timestamp
2. **Checkpoint system**: Kiểm tra bước nào đã hoàn thành
3. **Chạy từng bước**:
   - Nếu bước chưa chạy → chạy
   - Nếu bước đã chạy → bỏ qua
4. **Logging**: Ghi log ra cả terminal và file
5. **Tổng kết**: Tính thời gian tổng

**Checkpoint là gì?**
- Checkpoint = điểm đánh dấu bước đã hoàn thành
- Lưu trong `.pipeline_checkpoints/step_X.done`
- Mỗi file chứa timestamp hoàn thành

**Ví dụ:**
```bash
# Kiểm tra bước 1 đã chạy chưa
if is_step_completed 1; then
    log "⏭️  Bước 1 đã hoàn thành, đang bỏ qua..."
else
    # Chạy bước 1
    python "02_scripts/polars/explore_fast.py"
    # Đánh dấu hoàn thành
    mark_step_completed 1
fi
```

**Lợi ích:**
- ✅ **Resume từ bước bị lỗi**: Nếu bước 4 lỗi → chạy lại từ bước 4, không cần chạy lại bước 1-3
- ✅ **Tiết kiệm thời gian**: Không chạy lại bước đã hoàn thành
- ✅ **Debugging dễ**: Có thể chạy từng bước riêng lẻ

**Reset checkpoints:**
```bash
./02_scripts/pipeline/reset_pipeline.sh  # Xóa tất cả checkpoints
```

---

### Câu 20: Jupyter Notebook
**Câu hỏi:** Làm sao để chạy phân tích trong Jupyter Notebook với kernel Spark?

**Câu trả lời:**

**Setup Jupyter Kernel cho Spark:**

```bash
# 1. Chạy script setup
./02_scripts/setup/setup_jupyter_kernel.sh

# Script sẽ tự động:
# - Cài đặt jupyter, ipykernel
# - Tạo kernel "pyspark-env"
# - Cấu hình SPARK_HOME, PYSPARK_PYTHON
```

**Khởi động Jupyter:**

```bash
# 1. Activate virtual environment
source .venv/bin/activate

# 2. Start JupyterLab
jupyter lab

# 3. Chọn kernel "pyspark-env" trong notebook
```

**Code trong notebook:**

```python
# Import
import pyspark
from pyspark.sql import SparkSession
import polars as pl

# Tạo Spark session
spark = SparkSession.builder \
    .appName("Analysis") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://localhost:9000") \
    .getOrCreate()

# Đọc dữ liệu từ HDFS
df = spark.read.csv("hdfs://localhost:9000/user/spark/hi_large/input/hadoop_input.txt")

# Phân tích
df.describe().show()

# Đọc kết quả bằng Polars
results = pl.read_csv("01_data/results/clustered_results.txt")
```

**Notebook có sẵn:**
- `06_visualizations/phan-tich.ipynb` - Phân tích và visualization

---

## 🚀 PHẦN 7: HIỆU NĂNG & TỐI ƯU (10%)

### Câu 21: Tối ưu Spark
**Câu hỏi:** Các cấu hình Spark nào giúp tăng tốc độ? Giải thích từng config.

**Câu trả lời:**

**Cấu hình Spark trong dự án:**

```python
spark = SparkSession.builder \
    .config("spark.driver.memory", "8g") \           # RAM cho driver
    .config("spark.executor.memory", "8g") \         # RAM cho mỗi executor
    .config("spark.executor.instances", "4") \       # 4 executors
    .config("spark.executor.cores", "4") \           # 4 cores/executor
    .config("spark.sql.shuffle.partitions", "800") \ # Số phần chia shuffle
    .config("spark.default.parallelism", "800") \    # Song song hóa
    .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \  # Serializer nhanh
    .config("spark.kryoserializer.buffer.max", "512m") \  # Buffer lớn
    .config("spark.sql.adaptive.enabled", "true") \  # AQE
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \  # Gộp partition
    .getOrCreate()
```

**Giải thích:**

1. **Memory configs:**
   - `driver.memory = 8g`: RAM cho driver (coordinator)
   - `executor.memory = 8g`: RAM cho mỗi executor (worker)
   - **Tổng RAM**: 8 + (8 × 4) = 40GB

2. **Parallelism:**
   - `executor.instances = 4`: 4 workers làm việc song song
   - `executor.cores = 4`: Mỗi worker có 4 CPU cores
   - **Tổng cores**: 4 × 4 = 16 cores (16 tasks cùng lúc)

3. **Shuffle optimization:**
   - `shuffle.partitions = 800`: Chia dữ liệu thành 800 phần khi shuffle
   - **Lý do**: 800 partitions cho 16 cores → mỗi core xử lý ~50 partitions

4. **Serialization:**
   - `KryoSerializer`: Nhanh hơn Java serializer 10x
   - `buffer.max = 512m`: Buffer lớn để tránh tràn

5. **Adaptive Query Execution (AQE):**
   - `adaptive.enabled = true`: Spark tự động điều chỉnh query plan
   - `coalescePartitions = true`: Gộp các partition nhỏ lại
   - **Lợi ích**: Giảm overhead, tăng tốc độ 20-30%

---

### Câu 22: So sánh Polars vs Pandas
**Câu hỏi:** Em hãy so sánh hiệu năng Polars vs Pandas trong dự án này?

**Câu trả lời:**

**Benchmark thực tế (16GB CSV, 179M rows):**

| Thao tác | Pandas | Polars | Nhanh hơn |
|----------|--------|--------|-----------|
| Đọc CSV | ~45 phút | ~5 phút | 9x |
| Filter 100M rows | ~30 giây | ~3 giây | 10x |
| GroupBy + Aggregation | ~60 giây | ~6 giây | 10x |
| Feature Engineering | ~120 giây | ~36 giây | 3.3x |

**Lý do Polars nhanh hơn:**

1. **Rust backend**: Polars viết bằng Rust (nhanh như C++), Pandas viết bằng Python
2. **Columnar format**: Apache Arrow (columnar) nhanh hơn row-based
3. **Lazy evaluation**: Polars tối ưu query trước khi thực thi
4. **Parallel processing**: Polars tự động dùng tất cả CPU cores
5. **Memory efficient**: Streaming mode xử lý file lớn hơn RAM

**Code so sánh:**

```python
# Pandas (chậm)
df = pd.read_csv('16GB.csv')  # Load hết vào RAM
df = df.groupby('col').sum()  # Single-threaded

# Polars (nhanh)
df = pl.scan_csv('16GB.csv')  # Lazy, không load hết
df = df.groupby('col').sum()  # Multi-threaded
df.sink_csv('output.csv')     # Streaming
```

**Khi nào dùng Pandas?**
- File nhỏ (<1GB)
- Cần compatibility với thư viện khác (sklearn, matplotlib)
- Team đã quen Pandas API

**Khi nào dùng Polars?**
- File lớn (>1GB)
- Cần tốc độ cao
- Xử lý Big Data (kết hợp với Spark)

---

### Câu 23: Bottleneck
**Câu hỏi:** Bước nào chậm nhất trong pipeline? Làm sao tối ưu?

**Câu trả lời:**

**Phân tích thời gian (11 phút 22 giây tổng):**

| Bước | Thời gian | % Tổng | Bottleneck? |
|------|-----------|--------|-------------|
| 1. Explore | 13s | 1.9% | ✅ Nhanh |
| 2. Feature Engineering | 36s | 5.3% | ✅ Nhanh |
| 3. Upload HDFS | 41s | 6.0% | ⚠️ I/O bound |
| **4. K-means MLlib** | **365s** | **53.5%** | ❌ **CHẬM NHẤT** |
| 5. Download | 3s | 0.4% | ✅ Nhanh |
| 6. Assign clusters | 194s | 28.5% | ⚠️ Chậm thứ 2 |
| 7. Analyze | 30s | 4.4% | ✅ Nhanh |

**Bottleneck 1: K-means MLlib (6 phút 5 giây, 53.5%)**

**Nguyên nhân:**
- Phải lặp 15 iterations
- Mỗi iteration tính khoảng cách cho 179M điểm
- Shuffle data giữa các executors

**Cách tối ưu:**
1. ✅ **Đã làm**: Dùng MLlib (nhanh hơn RDD 30-50%)
2. ✅ **Đã làm**: k-means++ giảm số iterations (15 → 10-12)
3. ⚠️ **Có thể làm thêm**:
   - Tăng số executors (4 → 8): Giảm 30-40% thời gian
   - Tăng RAM (8GB → 16GB): Giảm spill to disk
   - Giảm K (5 → 3): Giảm 20% thời gian
   - Sample data (179M → 50M): Giảm 70% thời gian (nhưng mất accuracy)

**Bottleneck 2: Assign clusters (3 phút 14 giây, 28.5%)**

**Nguyên nhân:**
- Phải tính khoảng cách 179M × 5 = 895M lần
- Đọc streaming từ HDFS (network I/O)

**Cách tối ưu:**
1. ✅ **Đã làm**: NumPy vectorization (nhanh hơn Python loop 100x)
2. ✅ **Đã làm**: Batch processing (1M mỗi lần, không tràn RAM)
3. ⚠️ **Có thể làm thêm**:
   - Dùng Spark để assign (song song trên cluster)
   - Tăng batch size (1M → 5M nếu RAM đủ)
   - Dùng Cython/Numba JIT compile

**Tối ưu tổng thể:**
- Với cấu hình hiện tại: **11 phút** (rất tốt cho 179M rows!)
- Nếu tăng cluster (8 executors): **~7-8 phút**
- Nếu sample 50%: **~5-6 phút** (nhưng mất accuracy)

---

Đây là file câu hỏi chi tiết bao gồm:
- **23 câu hỏi** chia thành **7 phần**
- **Câu trả lời chi tiết** cho mỗi câu
- Bao gồm code, so sánh, phân tích

Mỗi câu hỏi được thiết kế để:
- Kiểm tra hiểu biết sâu về dự án
- Yêu cầu giải thích code
- Phân tích workflow, công nghệ, hiệu năng
- Đánh giá khả năng tư duy phản biện
