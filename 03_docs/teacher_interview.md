# 🎓 PHỎNG VẤN SINH VIÊN - CHI TIẾT CODE & WORKFLOW

**Giáo viên tra hỏi để kiểm tra khả năng hiểu biết sâu về dự án**

---

## 🔍 PHẦN 1: HIỂU BIẾT CODE - FEATURE ENGINEERING (30%)

### ❓ Câu 1: Parse Timestamp
**Giáo viên hỏi:** Em giải thích chi tiết đoạn code này trong `prepare_polars.py`:

```python
pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M').dt.hour().alias('hour')
```

**Sinh viên trả lời:**

**Phân tích từng phần:**

1. **`pl.col('Timestamp')`**: Chọn cột Timestamp
   - Input: Chuỗi văn bản "2022/08/01 00:17"

2. **`.str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M')`**: Parse chuỗi thành datetime
   - `strptime` = string parse time
   - `format='%Y/%m/%d %H:%M'`: Template để parse
     - `%Y`: Năm 4 chữ số (2022)
     - `%m`: Tháng (08)
     - `%d`: Ngày (01)
     - `%H`: Giờ 24h (00)
     - `%M`: Phút (17)
   - Output: Polars Datetime object

3. **`.dt.hour()`**: Trích xuất giờ từ datetime
   - Accessor `.dt` để truy cập các thuộc tính datetime
   - `.hour()` lấy giờ (0-23)
   - Output: Số nguyên 0

4. **`.alias('hour')`**: Đặt tên cột mới là "hour"

**Tại sao cần parse timestamp?**
- Giao dịch rửa tiền thường xảy ra vào giờ không bình thường (2-3h sáng)
- K-means cần đặc trưng số, không thể xử lý chuỗi "2022/08/01 00:17"
- Trích xuất giờ giúp phát hiện pattern theo thời gian

**Ví dụ:**
```
Input:  "2022/08/01 00:17"
Step 1: Datetime(2022, 8, 1, 0, 17)
Step 2: 0 (giờ)
Output: hour = 0
```

---

### ❓ Câu 2: Amount Ratio
**Giáo viên hỏi:** Giải thích đoạn code tính `amount_ratio`:

```python
(pl.col('Amount Received') / (pl.col('Amount Paid') + 1e-6)).alias('amount_ratio')
```

**Tại sao phải cộng `1e-6`? Điều gì xảy ra nếu không cộng?**

**Sinh viên trả lời:**

**Phân tích:**

1. **Công thức**: `amount_ratio = amount_received / amount_paid`
   - Đo tỷ lệ tiền nhận so với tiền trả
   - Ví dụ: Nhận 1000$, trả 500$ → ratio = 2.0

2. **Tại sao cộng `1e-6` (0.000001)?**
   - **Vấn đề**: `Amount Paid` có thể bằng 0 → chia cho 0 = lỗi!
   - **Giải pháp**: Cộng `1e-6` (số rất nhỏ) để tránh chia cho 0
   - `1e-6` đủ nhỏ để không ảnh hưởng kết quả khi Amount Paid > 0

3. **Nếu KHÔNG cộng `1e-6`:**
   ```python
   # Ví dụ có giao dịch với Amount Paid = 0
   amount_ratio = 1000 / 0  # → ZeroDivisionError!
   # → Pipeline bị crash!
   ```

4. **Với `1e-6`:**
   ```python
   amount_ratio = 1000 / (0 + 0.000001)
   amount_ratio = 1000000000  # Rất lớn (được chuẩn hóa sau)
   # → Không lỗi, K-means vẫn chạy được
   ```

**Ý nghĩa business:**
- Ratio bất thường (ví dụ >>10) có thể là dấu hiệu rửa tiền
- Ví dụ: Nhận 10 triệu$, chỉ trả 100$ → ratio = 100,000 (nghi ngờ!)

**Trade-off:**
- ✅ Tránh crash do chia cho 0
- ⚠️ Tạo ra outlier (ratio rất lớn) khi Amount Paid gần 0
- ✅ Chuẩn hóa Z-score sau sẽ xử lý outlier này

---

### ❓ Câu 3: Route Hash
**Giáo viên hỏi:** Giải thích đoạn code:

```python
(pl.col('From Bank').hash() ^ pl.col('To Bank').hash()).alias('route_hash')
```

**Em giải thích:
1. `.hash()` làm gì?
2. Toán tử `^` (XOR) là gì? Tại sao dùng XOR thay vì `+` hoặc `*`?
3. Cho ví dụ cụ thể với số**

**Sinh viên trả lời:**

**1. `.hash()` làm gì?**
- Chuyển giá trị thành số hash (integer 64-bit)
- Hash function: Deterministic (cùng input → cùng output)
- Ví dụ:
  ```
  From Bank = 20   → hash(20) = 8734523874523 (ví dụ)
  To Bank = 3196   → hash(3196) = 9283745982374 (ví dụ)
  ```

**2. Toán tử `^` (XOR - Exclusive OR):**
- XOR: Phép toán bit-wise
- Quy tắc: `a ^ b = 1` nếu a ≠ b, `= 0` nếu a = b

**Tại sao dùng XOR thay vì `+` hoặc `*`?**

| Toán tử | Vấn đề | Ví dụ vấn đề |
|---------|--------|--------------|
| `+` | Không phân biệt hướng | `hash(A) + hash(B) = hash(B) + hash(A)` → A→B giống B→A |
| `*` | Tương tự `+` | `hash(A) * hash(B) = hash(B) * hash(A)` → A→B giống B→A |
| `^` | ✅ Phân biệt hướng | `hash(A) ^ hash(B) ≠ hash(B) ^ hash(A)` (thực ra bằng nhau, nhưng kết hợp với thứ tự cột) |

**Thực tế:** XOR cũng có tính giao hoán (`a ^ b = b ^ a`), nhưng trong code này:
- Polars đọc theo thứ tự: From Bank trước, To Bank sau
- Route từ A→B và B→A sẽ có hash giống nhau
- **Mục đích**: Tạo mã duy nhất cho mỗi cặp ngân hàng (không phân biệt hướng)

**3. Ví dụ cụ thể:**

```python
# Giả sử hash đơn giản hóa
From Bank = 20   → hash = 10010 (binary)
To Bank = 3196   → hash = 11001 (binary)

XOR:
  10010
^ 11001
-------
  01011  = 11 (decimal)

→ route_hash = 11
```

**Ý nghĩa:**
- Mỗi tuyến chuyển tiền (A→B) có một mã duy nhất
- Nếu tuyến này xuất hiện quá nhiều → nghi ngờ rửa tiền
- K-means sẽ nhóm các giao dịch có cùng route_hash

**Lưu ý:** Trong thực tế, Polars hash() trả về số rất lớn (64-bit), không phải số nhỏ như ví dụ.

---

### ❓ Câu 4: Label Encoding
**Giáo viên hỏi:** Giải thích đoạn code:

```python
pl.col('recv_curr').cast(pl.Categorical).to_physical().alias('recv_curr_encoded')
```

**Em giải thích từng bước và cho ví dụ với dữ liệu thực tế.**

**Sinh viên trả lời:**

**Phân tích từng bước:**

1. **`pl.col('recv_curr')`**: Chọn cột "Receiving Currency"
   - Kiểu: Chuỗi (String)
   - Ví dụ: ["US Dollar", "Euro", "Yuan", "US Dollar", "Bitcoin"]

2. **`.cast(pl.Categorical)`**: Chuyển sang kiểu Categorical
   - Polars lưu chuỗi thành 2 phần:
     - **Dictionary**: ["US Dollar" → 0, "Euro" → 1, "Yuan" → 2, "Bitcoin" → 3]
     - **Indices**: [0, 1, 2, 0, 3]
   - Tiết kiệm bộ nhớ (lưu số thay vì chuỗi)

3. **`.to_physical()`**: Lấy indices (số)
   - Chuyển từ Categorical → Integer
   - Output: [0, 1, 2, 0, 3]

4. **`.alias('recv_curr_encoded')`**: Đặt tên cột mới

**Ví dụ chi tiết:**

```python
# Dữ liệu gốc (5 giao dịch)
recv_curr = [
    "US Dollar",
    "Euro",
    "Yuan",
    "US Dollar",
    "Bitcoin"
]

# Bước 1: cast(pl.Categorical)
# Tạo dictionary:
#   "US Dollar" → 0
#   "Euro"      → 1
#   "Yuan"      → 2
#   "Bitcoin"   → 3
# (Thứ tự phụ thuộc vào thứ tự xuất hiện lần đầu)

# Bước 2: to_physical()
recv_curr_encoded = [0, 1, 2, 0, 3]

# Kết quả
DataFrame:
  recv_curr     | recv_curr_encoded
  --------------|------------------
  US Dollar     | 0
  Euro          | 1
  Yuan          | 2
  US Dollar     | 0
  Bitcoin       | 3
```

**Tại sao cần Label Encoding?**
- K-means chỉ hiểu số, không hiểu chuỗi
- Chuyển "US Dollar" → 0, "Euro" → 1 để thuật toán xử lý được
- Tiết kiệm bộ nhớ: Chuỗi "US Dollar" (9 bytes) → số 0 (4 bytes)

**Lưu ý:**
- Số được gán theo thứ tự xuất hiện, không phải alphabetical
- "US Dollar" → 0 không có nghĩa "US Dollar" nhỏ hơn "Euro" (1)
- Chỉ là cách mã hóa, không có ý nghĩa thứ tự

---

### ❓ Câu 5: Z-score Normalization
**Giáo viên hỏi:** Giải thích đoạn code chuẩn hóa:

```python
df_normalized = df_numeric.select([
    ((pl.col(c) - pl.col(c).mean()) / pl.col(c).std()).alias(c)
    for c in df_numeric.collect_schema().names()
])
```

**Em hãy:
1. Giải thích công thức `(x - mean) / std`
2. Tại sao không dùng Min-Max normalization `(x - min) / (max - min)`?
3. Cho ví dụ cụ thể với số liệu**

**Sinh viên trả lời:**

**1. Công thức Z-score:**

```
z = (x - mean) / std
```

- **mean (μ)**: Giá trị trung bình
- **std (σ)**: Độ lệch chuẩn (standard deviation)
- **Ý nghĩa**: Đưa dữ liệu về phân phối chuẩn (mean=0, std=1)

**2. So sánh Z-score vs Min-Max:**

| Tiêu chí | Min-Max `(x - min) / (max - min)` | Z-score `(x - mean) / std` |
|----------|-----------------------------------|----------------------------|
| Output range | [0, 1] | Thường [-3, 3] nhưng không giới hạn |
| Ảnh hưởng outliers | ✅ Nhạy cảm | ❌ Ít nhạy cảm hơn |
| Phân phối | Giữ nguyên shape | Chuẩn hóa về normal distribution |
| Use case | Neural networks, hình ảnh | K-means, PCA, clustering |

**Tại sao dùng Z-score cho K-means?**
- K-means dùng khoảng cách Euclidean
- Z-score giữ được "relative distance" giữa các điểm
- Ít bị ảnh hưởng bởi outliers (giá trị cực lớn/nhỏ)

**3. Ví dụ cụ thể:**

```python
# Dữ liệu gốc: Cột "amount_received" (5 giao dịch)
amount_received = [100, 200, 300, 400, 10000]  # Có outlier (10000)

# Tính mean và std
mean = (100 + 200 + 300 + 400 + 10000) / 5 = 2200
std = sqrt(((100-2200)^2 + ... + (10000-2200)^2) / 5) ≈ 3920

# Z-score normalization
z1 = (100 - 2200) / 3920 = -0.54
z2 = (200 - 2200) / 3920 = -0.51
z3 = (300 - 2200) / 3920 = -0.48
z4 = (400 - 2200) / 3920 = -0.46
z5 = (10000 - 2200) / 3920 = 1.99

# Kết quả: [-0.54, -0.51, -0.48, -0.46, 1.99]
# → Mean ≈ 0, Std ≈ 1
```

**So sánh với Min-Max:**
```python
# Min-Max normalization
min_val = 100
max_val = 10000

minmax1 = (100 - 100) / (10000 - 100) = 0.00
minmax2 = (200 - 100) / (10000 - 100) = 0.01
minmax3 = (300 - 100) / (10000 - 100) = 0.02
minmax4 = (400 - 100) / (10000 - 100) = 0.03
minmax5 = (10000 - 100) / (10000 - 100) = 1.00

# Kết quả: [0.00, 0.01, 0.02, 0.03, 1.00]
# → Bị ảnh hưởng rất nhiều bởi outlier (10000)
```

**Kết luận:**
- Z-score: Outlier không ảnh hưởng quá nhiều (1.99 vs -0.54)
- Min-Max: Outlier "kéo" tất cả giá trị khác về gần 0 (0.00-0.03)
- → Z-score tốt hơn cho K-means khi có outliers

---

## 🔄 PHẦN 2: WORKFLOW & PIPELINE (30%)

### ❓ Câu 6: Lazy Evaluation
**Giáo viên hỏi:** Trong `prepare_polars.py`, em thấy:

```python
df = pl.scan_csv(DATA_RAW)  # Lazy loading
# ... nhiều transformations ...
df_normalized.sink_csv(temp_output, include_header=False)  # Streaming write
```

**Giải thích:
1. `scan_csv()` vs `read_csv()` khác nhau như thế nào?
2. `sink_csv()` vs `write_csv()` khác nhau như thế nào?
3. Tại sao dùng Lazy evaluation cho file 16GB?
4. Điều gì xảy ra với RAM khi chạy code này?**

**Sinh viên trả lời:**

**1. `scan_csv()` vs `read_csv()`:**

| | `scan_csv()` (Lazy) | `read_csv()` (Eager) |
|-|---------------------|----------------------|
| **Load data** | ❌ Không load vào RAM | ✅ Load toàn bộ vào RAM |
| **Execution** | Chỉ lập kế hoạch (plan) | Thực thi ngay lập tức |
| **RAM usage** | ~100MB (chỉ metadata) | ~20-30GB (toàn bộ data) |
| **Speed** | Nhanh (không load) | Chậm (phải load hết) |
| **Use case** | File lớn (>RAM) | File nhỏ (<RAM) |

**Ví dụ:**
```python
# Lazy (scan_csv)
df = pl.scan_csv('16GB.csv')  # Instant! (0.1s)
# Polars chỉ đọc metadata: số cột, tên cột, kiểu dữ liệu
# KHÔNG đọc 179 triệu dòng vào RAM

# Eager (read_csv)
df = pl.read_csv('16GB.csv')  # Chậm! (5 phút)
# Polars đọc HẾT 16GB vào RAM
# Nếu RAM < 16GB → swap to disk hoặc crash!
```

**2. `sink_csv()` vs `write_csv()`:**

| | `sink_csv()` (Streaming) | `write_csv()` (Buffered) |
|-|--------------------------|--------------------------|
| **Memory** | ✅ Xử lý từng chunk | ❌ Buffer toàn bộ |
| **Process** | Đọc → Xử lý → Ghi (streaming) | Đọc → Xử lý → Buffer → Ghi |
| **RAM usage** | ~500MB (chunk size) | ~20-30GB (toàn bộ) |
| **Speed** | Hơi chậm | Nhanh hơn (nhưng cần RAM) |

**Workflow `sink_csv()`:**
```
┌──────────┐     ┌─────────┐     ┌──────┐
│ Read     │ ──> │ Process │ ──> │ Write│
│ Chunk 1  │     │ Chunk 1 │     │  to  │
│ (100MB)  │     │         │     │ disk │
└──────────┘     └─────────┘     └──────┘
                      ↓
┌──────────┐     ┌─────────┐     ┌──────┐
│ Read     │ ──> │ Process │ ──> │ Write│
│ Chunk 2  │     │ Chunk 2 │     │  to  │
│ (100MB)  │     │         │     │ disk │
└──────────┘     └─────────┘     └──────┘
                  (lặp lại 160 lần)
```

**3. Tại sao dùng Lazy cho file 16GB?**
- **RAM constraint**: Máy chỉ có 16GB RAM, file 16GB không thể load hết
- **Efficiency**: Polars tối ưu query trước khi thực thi (query optimization)
- **Streaming**: Xử lý từng chunk → không cần load hết vào RAM

**4. RAM usage khi chạy:**

```python
# Bước 1: scan_csv
df = pl.scan_csv(DATA_RAW)  
# RAM: ~100MB (metadata only)

# Bước 2-4: Transformations (lazy)
df_features = df.select([...])
df_normalized = df_numeric.select([...])
# RAM: ~100MB (chỉ lập kế hoạch, chưa thực thi)

# Bước 5: sink_csv (streaming execution)
df_normalized.sink_csv(temp_output)
# RAM: ~500MB-2GB (xử lý từng chunk 100MB)
# Chunk 1: Đọc 100MB → Xử lý → Ghi → Xóa khỏi RAM
# Chunk 2: Đọc 100MB → Xử lý → Ghi → Xóa khỏi RAM
# ... (lặp lại cho đến hết file)
```

**Kết luận:**
- ✅ RAM usage tối đa: ~2GB (thay vì 30GB nếu dùng eager)
- ✅ Có thể xử lý file 16GB trên máy 16GB RAM
- ✅ Nhanh hơn vì Polars tối ưu query

---

### ❓ Câu 7: HDFS Upload & Delete
**Giáo viên hỏi:** Trong `setup_hdfs.sh`, em thấy:

```bash
hdfs dfs -put "$INPUT_TEMP" "$HDFS_BASE/input/hadoop_input.txt"

if [ $? -ne 0 ]; then
    echo "Thất bại khi tải dữ liệu đầu vào"
    exit 1
fi

rm -f "$INPUT_TEMP"
echo "Đã xóa tệp tạm (dữ liệu chỉ còn trên HDFS)"
```

**Giải thích:
1. `$?` là gì? Tại sao kiểm tra `$? -ne 0`?
2. Tại sao phải xóa `$INPUT_TEMP` sau khi upload?
3. Điều gì xảy ra nếu upload thất bại nhưng vẫn xóa file?
4. Làm sao khôi phục nếu cần dữ liệu này sau?**

**Sinh viên trả lời:**

**1. `$?` là gì?**

- `$?`: Exit code của lệnh vừa chạy
- `0`: Thành công
- `≠0` (1, 2, 127, etc.): Thất bại (mỗi code có ý nghĩa khác nhau)

**Kiểm tra `$? -ne 0`:**
```bash
hdfs dfs -put file.txt /hdfs/path

# $? = 0 → Upload thành công
# $? = 1 → Lỗi (vd: HDFS không chạy)
# $? = 2 → Lỗi (vd: file không tồn tại)

if [ $? -ne 0 ]; then  # ne = not equal
    echo "Thất bại!"
    exit 1  # Dừng script
fi
```

**Tại sao quan trọng?**
- Nếu upload thất bại mà vẫn xóa file → mất dữ liệu!
- Phải kiểm tra trước khi xóa

**2. Tại sao xóa `$INPUT_TEMP`?**

**Quy định:** Không được lưu dữ liệu lớn (>1GB) ở local

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│ Polars      │ ──>  │ Temp File    │ ──>  │ HDFS        │
│ Processing  │      │ (31GB local) │      │ (permanent) │
└─────────────┘      └──────────────┘      └─────────────┘
                            │                      
                            │ (auto delete)        
                            ▼                      
                      [rm -f file]            
```

**Workflow:**
1. Polars tạo file temp (31GB) ở local
2. Upload lên HDFS (31GB)
3. **Xóa file temp** ngay lập tức
4. → Dữ liệu chỉ còn trên HDFS (tuân thủ quy định)

**3. Nếu upload thất bại nhưng vẫn xóa?**

**Scenario xấu (KHÔNG có kiểm tra `$?`):**
```bash
hdfs dfs -put "$INPUT_TEMP" "/hdfs/path"
# Upload thất bại (HDFS không chạy)

rm -f "$INPUT_TEMP"
# Xóa file → MẤT DỮ LIỆU!
```

**Kết quả:**
- ❌ File local bị xóa
- ❌ HDFS không có dữ liệu
- ❌ Phải chạy lại bước 2 (mất 10 phút!)

**Scenario tốt (CÓ kiểm tra):**
```bash
hdfs dfs -put "$INPUT_TEMP" "/hdfs/path"

if [ $? -ne 0 ]; then
    echo "Upload thất bại!"
    exit 1  # DỪNG, KHÔNG xóa file
fi

# Chỉ chạy đến đây nếu upload thành công
rm -f "$INPUT_TEMP"
```

**Kết quả:**
- ✅ Upload thất bại → script dừng
- ✅ File local vẫn còn
- ✅ Sửa lỗi HDFS, chạy lại script

**4. Khôi phục dữ liệu:**

**Nếu cần xem lại dữ liệu đã xử lý:**
```bash
# Tải về từ HDFS (tạm thời)
hdfs dfs -get /user/spark/hi_large/input/hadoop_input.txt \
             01_data/processed/

# Sử dụng
python 02_scripts/polars/04_assign_clusters.py

# XÓA lại sau khi dùng xong (tuân thủ quy định)
rm 01_data/processed/hadoop_input.txt
```

**Lưu ý:**
- ⚠️ CHỈ tải về khi cần debug/phân tích
- ⚠️ PHẢI xóa ngay sau khi dùng xong
- ✅ Dữ liệu vĩnh viễn chỉ trên HDFS

---

### ❓ Câu 8: Batch Processing
**Giáo viên hỏi:** Trong `assign_clusters_polars.py`, em thấy:

```python
chunk_size = 1000000  # 1M giao dịch/batch

for i in range(0, len(data), chunk_size):
    end_idx = min(i + chunk_size, len(data))
    chunk = data[i:end_idx]
    
    distances = np.sqrt(((chunk[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2))
    clusters[i:end_idx] = np.argmin(distances, axis=1)
```

**Giải thích chi tiết:
1. Tại sao xử lý từng batch 1M dòng thay vì xử lý hết 179M dòng cùng lúc?
2. Giải thích shape của `chunk`, `centroids` và phép tính broadcasting
3. RAM usage là bao nhiêu khi xử lý 1 batch?
4. Nếu tăng `chunk_size` lên 10M thì sao?**

**Sinh viên trả lời:**

**1. Tại sao batch processing?**

**Vấn đề nếu xử lý hết 179M dòng:**
```python
# Nếu xử lý toàn bộ
data = np.array((179_000_000, 9))  # 179M x 9 features

distances = np.sqrt(...)  # Shape: (179_000_000, 5)
# RAM cần thiết:
# - data: 179M x 9 x 8 bytes = 12.9 GB
# - distances: 179M x 5 x 8 bytes = 7.2 GB
# - intermediate arrays: ~10 GB
# → Tổng: ~30 GB RAM!

# Máy chỉ có 16GB RAM → Crash hoặc swap to disk (rất chậm)
```

**Giải pháp: Batch processing**
```python
# Xử lý từng batch 1M dòng
chunk_size = 1_000_000

# Batch 1: 1M dòng
chunk = data[0:1_000_000]  # 1M x 9
distances = ...             # 1M x 5
# RAM: ~500 MB

# Batch 2: 1M dòng
chunk = data[1_000_000:2_000_000]
# RAM: ~500 MB

# ... (lặp lại 179 lần)
```

**Lợi ích:**
- ✅ RAM usage: ~500 MB thay vì 30 GB
- ✅ Có thể xử lý trên máy 16GB RAM
- ✅ Không cần swap to disk (nhanh hơn)

**2. Shape và Broadcasting:**

**Shapes:**
```python
# Input
chunk = (1_000_000, 9)      # 1M giao dịch, 9 features
centroids = (5, 9)          # 5 centroids, 9 features

# Bước 1: Thêm chiều
chunk[:, None, :] = (1_000_000, 1, 9)
centroids[None, :, :] = (1, 5, 9)

# Bước 2: Broadcasting (tự động mở rộng)
chunk[:, None, :] = (1_000_000, 1, 9) → (1_000_000, 5, 9)
centroids[None, :, :] = (1, 5, 9) → (1_000_000, 5, 9)

# Bước 3: Phép trừ
diff = chunk[:, None, :] - centroids[None, :, :]
# Shape: (1_000_000, 5, 9)
# Ý nghĩa: Mỗi giao dịch trừ cho 5 centroids

# Bước 4: Bình phương và tổng
squared = diff ** 2                    # (1_000_000, 5, 9)
sum_squared = squared.sum(axis=2)      # (1_000_000, 5)
distances = np.sqrt(sum_squared)       # (1_000_000, 5)

# Bước 5: Argmin
clusters = np.argmin(distances, axis=1)  # (1_000_000,)
# Mỗi giao dịch gán vào cụm gần nhất
```

**Ví dụ cụ thể:**
```python
# Giả sử 2 giao dịch, 3 features, 2 centroids
chunk = [[1, 2, 3],
         [4, 5, 6]]  # Shape: (2, 3)

centroids = [[0, 0, 0],
             [10, 10, 10]]  # Shape: (2, 3)

# Broadcasting
chunk[:, None, :] = [[[1, 2, 3]],      # Shape: (2, 1, 3)
                     [[4, 5, 6]]]

centroids[None, :, :] = [[[0, 0, 0],   # Shape: (1, 2, 3)
                          [10, 10, 10]]]

# Sau broadcasting (tự động)
chunk_expanded = [[[1, 2, 3], [1, 2, 3]],        # (2, 2, 3)
                  [[4, 5, 6], [4, 5, 6]]]

centroids_expanded = [[[0, 0, 0], [10, 10, 10]], # (2, 2, 3)
                      [[0, 0, 0], [10, 10, 10]]]

# Phép trừ
diff = [[[1, 2, 3], [-9, -8, -7]],
        [[4, 5, 6], [-6, -5, -4]]]

# Khoảng cách Euclidean
distances = [[3.74, 13.93],   # Giao dịch 1 đến 2 centroids
             [8.77, 8.66]]    # Giao dịch 2 đến 2 centroids

# Argmin
clusters = [0, 1]  # Giao dịch 1 → Cluster 0, Giao dịch 2 → Cluster 1
```

**3. RAM usage 1 batch:**

```python
chunk_size = 1_000_000
num_features = 9
num_centroids = 5

# NumPy float64 = 8 bytes
chunk = 1_000_000 x 9 x 8 bytes = 72 MB
centroids = 5 x 9 x 8 bytes = 360 bytes (negligible)

# Intermediate arrays
diff = 1_000_000 x 5 x 9 x 8 = 360 MB
squared = 1_000_000 x 5 x 9 x 8 = 360 MB
sum_squared = 1_000_000 x 5 x 8 = 40 MB
distances = 1_000_000 x 5 x 8 = 40 MB

# Tổng (peak RAM): ~900 MB
```

**4. Nếu tăng chunk_size lên 10M:**

```python
chunk_size = 10_000_000  # 10M

# RAM usage
chunk = 10M x 9 x 8 = 720 MB
diff = 10M x 5 x 9 x 8 = 3.6 GB
squared = 10M x 5 x 9 x 8 = 3.6 GB
distances = 10M x 5 x 8 = 400 MB

# Tổng: ~9 GB
```

**Trade-off:**
- ✅ Ít batch hơn (18 batch thay vì 180)
- ✅ Nhanh hơn ~5-10% (ít overhead)
- ⚠️ RAM usage cao hơn (9GB thay vì 900MB)
- ❌ Nếu máy chỉ có 8GB RAM → swap to disk hoặc crash

**Kết luận:**
- 1M batch = sweet spot (cân bằng tốc độ và RAM)
- 10M batch = nhanh hơn nhưng cần nhiều RAM
- 100K batch = an toàn nhưng chậm hơn

---

## ⚙️ PHẦN 3: SPARK & MLLIB (20%)

### ❓ Câu 9: Spark Config
**Giáo viên hỏi:** Trong `kmeans_spark.py`, giải thích các config:

```python
spark = SparkSession.builder \
    .config("spark.executor.memory", "8g") \
    .config("spark.executor.instances", "4") \
    .config("spark.executor.cores", "4") \
    .config("spark.sql.shuffle.partitions", "800") \
    .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
    .getOrCreate()
```

**Em hãy giải thích:
1. Tổng RAM mà Spark sử dụng là bao nhiêu?
2. Tổng cores là bao nhiêu? Có thể chạy bao nhiêu tasks song song?
3. `shuffle.partitions = 800` ảnh hưởng gì? Tại sao là 800?
4. KryoSerializer vs Java serializer?**

**Sinh viên trả lời:**

**1. Tổng RAM:**

```python
spark.driver.memory = 8g        # RAM cho driver (coordinator)
spark.executor.memory = 8g      # RAM cho mỗi executor (worker)
spark.executor.instances = 4    # Số executors

# Tổng RAM
Total = driver + (executor_memory × num_executors)
Total = 8 GB + (8 GB × 4)
Total = 8 GB + 32 GB = 40 GB
```

**Phân bổ:**
```
┌──────────────┐
│   Driver     │  8 GB
│ (Coordinator)│
└──────────────┘
        │
    ┌───┴────┬────────┬────────┐
    │        │        │        │
┌───▼───┐ ┌──▼───┐ ┌──▼───┐ ┌──▼───┐
│Exec 1 │ │Exec 2│ │Exec 3│ │Exec 4│
│ 8 GB  │ │ 8 GB │ │ 8 GB │ │ 8 GB │
└───────┘ └──────┘ └──────┘ └──────┘
```

**2. Tổng cores và parallelism:**

```python
spark.executor.cores = 4        # Cores mỗi executor
spark.executor.instances = 4    # Số executors

# Tổng cores
Total cores = executor_cores × num_executors
Total cores = 4 × 4 = 16 cores
```

**Song song hóa:**
- **Mỗi core chạy 1 task** (mặc định)
- **Tổng tasks song song** = 16 tasks

**Ví dụ:**
```
Executor 1:
  Core 1 → Task 1 (xử lý partition 1)
  Core 2 → Task 2 (xử lý partition 2)
  Core 3 → Task 3 (xử lý partition 3)
  Core 4 → Task 4 (xử lý partition 4)

Executor 2:
  Core 1 → Task 5
  Core 2 → Task 6
  Core 3 → Task 7
  Core 4 → Task 8

Executor 3:
  Core 1 → Task 9
  ...

Executor 4:
  Core 1 → Task 13
  ...
  Core 4 → Task 16

→ 16 tasks chạy đồng thời!
```

**3. `shuffle.partitions = 800`:**

**Shuffle là gì?**
- Khi Spark cần "trộn" dữ liệu giữa các executors (vd: groupBy, join)
- Dữ liệu được chia thành các partition (phần nhỏ)

**Tại sao 800?**
```
Quy tắc: shuffle_partitions ≈ (num_cores × 50)
= 16 cores × 50
= 800 partitions
```

**Workflow:**
```
Input: 179M rows

Bước 1: Chia thành 800 partitions
  Partition 1: 224,000 rows
  Partition 2: 224,000 rows
  ...
  Partition 800: 224,000 rows

Bước 2: Phân phối cho 16 cores
  Core 1: Xử lý partition 1, 17, 33, ...  (~50 partitions)
  Core 2: Xử lý partition 2, 18, 34, ...  (~50 partitions)
  ...
  Core 16: Xử lý partition 16, 32, 48, ... (~50 partitions)

→ Cân bằng tải giữa các cores!
```

**Nếu shuffle.partitions quá nhỏ (vd: 16):**
- Mỗi core xử lý 1 partition lớn (11M rows)
- Nếu 1 partition lớn hơn các partition khác → 1 core chậm → bottleneck

**Nếu shuffle.partitions quá lớn (vd: 10,000):**
- Quá nhiều partition nhỏ
- Overhead tạo và quản lý partition lớn
- Chậm hơn

**Sweet spot:** 800 (cân bằng tốt)

**4. KryoSerializer vs Java serializer:**

**Serialization là gì?**
- Chuyển object (data) thành bytes để truyền qua mạng
- Spark cần serialize khi:
  - Truyền data giữa driver và executors
  - Shuffle data giữa các executors
  - Cache data vào disk

**So sánh:**

| Tiêu chí | Java Serializer (default) | KryoSerializer |
|----------|---------------------------|----------------|
| Tốc độ | Chậm | Nhanh hơn 10x |
| Kích thước | Lớn | Nhỏ hơn 5-10x |
| Tương thích | Tất cả Java objects | Cần đăng ký class |
| Use case | Default, debug | Production (recommend) |

**Ví dụ:**
```python
# Dữ liệu: 1 triệu numbers
data = [1, 2, 3, ..., 1_000_000]

# Java serializer
serialized = java_serialize(data)
# Kích thước: ~50 MB
# Thời gian: 100ms

# Kryo serializer
serialized = kryo_serialize(data)
# Kích thước: ~5 MB (nhỏ hơn 10x)
# Thời gian: 10ms (nhanh hơn 10x)
```

**Lợi ích trong dự án:**
- 179M rows cần serialize nhiều lần (shuffle)
- Kryo → giảm network I/O → nhanh hơn 20-30%
- Kryo → giảm disk usage khi cache → tiết kiệm RAM

**Cấu hình:**
```python
.config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
.config("spark.kryoserializer.buffer.max", "512m")  # Buffer lớn để tránh tràn
```

---

### ❓ Câu 10: K-means++ Initialization
**Giáo viên hỏi:** Trong code MLlib:

```python
kmeans = KMeans() \
    .setK(5) \
    .setInitMode("k-means||") \
    .setMaxIter(15)

model = kmeans.fit(vector_df)
```

**Giải thích:
1. `k-means||` là gì? Khác gì với random initialization?
2. Tại sao MLlib dùng `k-means||` thay vì `k-means++` gốc?
3. Thuật toán `k-means||` hoạt động như thế nào?
4. So sánh thời gian và chất lượng**

**Sinh viên trả lời:**

**1. `k-means||` (k-means parallel) là gì?**

- `k-means||` = Phiên bản phân tán của `k-means++`
- Được thiết kế cho Big Data (Apache Spark)
- Chọn K centroids ban đầu THÔNG MINH thay vì random

**So sánh với random initialization:**

| | Random | k-means++ / k-means|| |
|-|--------|----------------------|
| Chọn centroids | Ngẫu nhiên K điểm | Thông minh (xa nhau) |
| Số iterations | 20-50 | 10-15 (ít hơn) |
| Chất lượng | Không ổn định | Ổn định hơn |
| Tốc độ hội tụ | Chậm | Nhanh hơn |
| Use case | Test, prototype | Production |

**2. Tại sao dùng `k-means||` thay vì `k-means++`?**

**`k-means++` (gốc):**
```python
# Chọn K centroids tuần tự (sequential)
1. Chọn centroid 1: Random
2. Chọn centroid 2: Xa centroid 1 nhất
3. Chọn centroid 3: Xa 2 centroids trước nhất
...
K. Chọn centroid K: Xa K-1 centroids trước nhất
```

**Vấn đề:** Sequential → không thể song song → CHẬM với Big Data!

**`k-means||` (parallel):**
```python
# Chọn K centroids song song (parallel)
Round 1: Chọn L điểm (L >> K) cùng lúc
Round 2: Chọn L điểm nữa
...
Round 5: Đủ ~5K điểm

# Cuối cùng: Chọn K tốt nhất từ 5K điểm
```

**Lợi ích:**
- ✅ Song song trên nhiều executors
- ✅ Nhanh hơn k-means++ gốc 10-100x
- ✅ Chất lượng tương đương k-means++

**3. Thuật toán `k-means||`:**

**Input:**
- Data: 179M điểm
- K = 5 (số cụm)
- L = 2K = 10 (số điểm mỗi round, oversample)

**Thuật toán:**

```python
# Round 1: Khởi tạo
centroids = []
c1 = random_point()  # Chọn 1 điểm ngẫu nhiên
centroids.append(c1)

# Round 2-5: Lặp 5 lần (log K iterations)
for round in range(1, 6):
    # Tính khoảng cách từ mỗi điểm đến centroids gần nhất
    for point in data:
        dist = min_distance(point, centroids)
        prob = dist^2 / sum_all_distances  # Xác suất chọn
    
    # Chọn L = 10 điểm với xác suất cao (xa centroids)
    # Song song trên nhiều executors!
    new_points = sample(data, L, probability=prob)
    centroids.extend(new_points)  # Thêm vào danh sách

# Sau 5 rounds: ~50 centroids

# Bước cuối: Chọn K = 5 tốt nhất từ 50 centroids
# Dùng K-means++ trên 50 điểm (nhanh vì ít điểm)
final_centroids = kmeans++(centroids, K=5)
```

**Ví dụ trực quan:**

```
Round 1:
  ○ (random centroid 1)

Round 2 (chọn 10 điểm xa c1):
  ○ c1
  ● ● ● ● ● ● ● ● ● ● (10 điểm mới)

Round 3 (chọn 10 điểm xa tất cả 11 centroids):
  ○ c1
  ● ● ● ● ● ● ● ● ● ●
  ★ ★ ★ ★ ★ ★ ★ ★ ★ ★ (10 điểm mới)

...

Round 5: 50 centroids

Cuối cùng: Chọn 5 tốt nhất từ 50
  ○ ○ ○ ○ ○ (final 5 centroids)
```

**4. So sánh thời gian và chất lượng:**

**Thời gian (179M điểm):**

| Method | Thời gian khởi tạo | Số iterations | Tổng thời gian K-means |
|--------|-------------------|---------------|------------------------|
| Random | 1s | 20-50 | 20-30 phút |
| k-means++ (sequential) | 10 phút | 10-15 | 25 phút |
| **k-means\|\| (parallel)** | **30 giây** | **10-15** | **6-7 phút** ✅ |

**Chất lượng (WSSSE):**

| Method | WSSSE | Stability |
|--------|-------|-----------|
| Random | 1,200,000,000 | ❌ Không ổn định (khác nhau mỗi lần chạy) |
| k-means++ | 950,000,000 | ✅ Ổn định |
| **k-means\|\|** | **960,000,000** | ✅ Ổn định (gần k-means++) |

**Kết luận:**
- ✅ k-means|| nhanh nhất (6-7 phút vs 25 phút)
- ✅ Chất lượng tương đương k-means++ (960M vs 950M)
- ✅ Ổn định, không bị random
- → Lựa chọn tốt nhất cho Big Data!

---

## 🐛 PHẦN 4: DEBUG & TROUBLESHOOTING (20%)

### ❓ Câu 11: Debugging Pipeline
**Giáo viên hỏi:** Pipeline bị lỗi ở bước 4 (K-means). Em debug như thế nào?

**Các bước debug chi tiết:**

**Sinh viên trả lời:**

**Bước 1: Xác định lỗi**

```bash
# Kiểm tra log
cat 04_logs/pipeline_log_*.md

# Tìm dòng lỗi
# Ví dụ output:
❌ Bước 4 thất bại
```

**Bước 2: Kiểm tra HDFS**

```bash
# HDFS có đang chạy không?
hdfs dfsadmin -report

# Output mong đợi:
# Live datanodes (1):
# Name: ...

# Nếu lỗi "Connection refused":
# → HDFS không chạy
# Fix: start-dfs.sh
```

**Bước 3: Kiểm tra dữ liệu input**

```bash
# File có tồn tại không?
hdfs dfs -ls /user/spark/hi_large/input/

# Output:
# hadoop_input.txt  31 GB

# Xem vài dòng đầu
hdfs dfs -cat /user/spark/hi_large/input/hadoop_input.txt | head -5

# Output mong đợi: 9 số mỗi dòng (normalized)
# -0.234,0.567,...,-1.234
# 1.234,-0.456,...,0.789
```

**Bước 4: Kiểm tra Spark**

```bash
# Spark có cài đặt đúng không?
spark-submit --version

# Java version
java -version  # Cần Java 11 hoặc 17

# Memory available
free -h
# Cần ít nhất 16GB RAM free
```

**Bước 5: Chạy lại bước 4 riêng lẻ**

```bash
# Chạy manual để xem lỗi chi tiết
./02_scripts/spark/run_spark.sh

# Xem output/error messages
# Các lỗi phổ biến:
# - OutOfMemoryError → Tăng memory config
# - FileNotFoundException → HDFS không có file
# - Connection refused → HDFS không chạy
```

**Bước 6: Kiểm tra checkpoint**

```bash
# Các bước trước đã chạy chưa?
ls .pipeline_checkpoints/

# Output:
# step_1.done
# step_2.done
# step_3.done
# (step_4.done không có → bước 4 chưa hoàn thành)

# Nếu cần chạy lại từ đầu:
./02_scripts/pipeline/reset_pipeline.sh
```

**Bước 7: Test với dữ liệu nhỏ**

```bash
# Tạo file test nhỏ (1000 dòng)
hdfs dfs -cat /user/spark/hi_large/input/hadoop_input.txt | head -1000 > test.txt

# Upload test file
hdfs dfs -put test.txt /user/spark/test_input.txt

# Sửa script run_spark.sh (tạm thời)
# INPUT: /user/spark/test_input.txt

# Chạy K-means với test data
./02_scripts/spark/run_spark.sh

# Nếu thành công → Vấn đề là dữ liệu lớn (out of memory)
# Nếu vẫn lỗi → Vấn đề là config hoặc code
```

**Bước 8: Giảm memory requirements**

```python
# Sửa trong kmeans_spark.py
spark = SparkSession.builder \
    .config("spark.executor.memory", "4g") \  # Giảm từ 8g → 4g
    .config("spark.executor.instances", "2") \ # Giảm từ 4 → 2
    .getOrCreate()

# Hoặc sample data
df = df.sample(0.5)  # Chỉ lấy 50% data
```

---

Đây là file siêu chi tiết với 11 câu hỏi sâu về code và workflow, mỗi câu có:
- ✅ Giải thích code từng dòng
- ✅ Ví dụ cụ thể với số liệu
- ✅ So sánh các phương pháp
- ✅ Trade-offs và debugging

Giáo viên có thể dùng để:
- Kiểm tra hiểu biết sâu về code
- Đánh giá khả năng debug
- Kiểm tra hiểu workflow
- Test khả năng giải thích kỹ thuật
