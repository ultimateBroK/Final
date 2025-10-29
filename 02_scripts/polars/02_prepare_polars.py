#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BƯỚC 2: XỬ LÝ VÀ TRÍCH XUẤT ĐẶC TRƯNG (FEATURE ENGINEERING)

Mục đích:
- Chuyển dữ liệu thô thành dạng số để thuật toán K-means xử lý
- Trích xuất đặc trưng từ timestamp (giờ, ngày trong tuần)
- Tính toán các tỷ lệ (amount_ratio)
- Mã hóa biến phân loại (categorical encoding)
- Chuẩn hóa tất cả features về [0, 1]

Thời gian chạy: ~10 phút
Input: 01_data/raw/HI-Large_Trans.csv (16GB, 179M dòng)
Output: 01_data/processed/hadoop_input_temp.txt (33GB, TẠM THỜI)

⚠️  LƯU Ý: File output sẽ BỊ XÓA TỰ ĐỘNG sau khi upload lên HDFS!
"""

import polars as pl
import numpy as np
import os
import time
from datetime import datetime

# ==================== CẤU HÌNH ĐƯỜNG DẪN ====================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_RAW = os.path.join(ROOT_DIR, '01_data', 'raw', 'HI-Large_Trans.csv')
DATA_PROCESSED = os.path.join(ROOT_DIR, '01_data', 'processed')

# Tạo thư mục processed nếu chưa có
os.makedirs(DATA_PROCESSED, exist_ok=True)

def log_with_time(msg, step_start=None):
    """In message với timestamp và thời gian elapsed nếu có"""
    current_time = datetime.now().strftime("%H:%M:%S")
    if step_start:
        elapsed = time.time() - step_start
        print(f"[{current_time}] {msg} (mất {elapsed:.1f}s)")
    else:
        print(f"[{current_time}] {msg}")

PIPELINE_START = time.time()

print("="*70)
print("BƯỚC 2: XỬ LÝ VÀ TRÍCH XUẤT ĐẶC TRƯNG 🔧")
print("="*70)
log_with_time(f"Đọc tệp: {DATA_RAW}")
log_with_time("Vui lòng đợi (có thể mất 5-10 phút)...")
print()

# ==================== ĐỌC DỮ LIỆU ====================
step_start = time.time()
log_with_time("BƯỚC 2.1/6: Đang thiết lập đọc trì hoãn (không tải toàn bộ)...")
# Scan_csv = Lazy loading (không load hết vào RAM)
# Polars sẽ xử lý từng batch và streaming ra disk
df = pl.scan_csv(DATA_RAW)

log_with_time("Đã thiết lập đọc trì hoãn (không tốn RAM)", step_start)
print()

# ==================== TRÍCH XUẤT ĐẶC TRƯNG ====================
step_start = time.time()
log_with_time("BƯỚC 2.2/6: Đang trích xuất đặc trưng từ dữ liệu thô...")
log_with_time("   ├─ Timestamp → Giờ, Ngày trong tuần")
log_with_time("   ├─ Amount → Received, Paid, Ratio")
log_with_time("   ├─ Route → Hash(From Bank ⊕ To Bank)")
log_with_time("   └─ Currencies → Label encoding")

# Chọn và tạo các đặc trưng mới
df_features = df.select([
    # === ĐẶc trưng thời gian ===
    # Parse timestamp từ chuỗi sang datetime
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M').alias('datetime'),
    
    # === Đặc trưng cơ bản ===
    # Số tiền nhận được
    pl.col('Amount Received').alias('amount_received'),
    # Số tiền trả
    pl.col('Amount Paid').alias('amount_paid'),
    
    # === Đặc trưng tính toán ===
    # Tỷ lệ tiền nhận / tiền trả (+ 1e-6 để tránh chia cho 0)
    # Nếu ratio bất thường (ví dụ >>1) có thể là rửa tiền
    (pl.col('Amount Received') / (pl.col('Amount Paid') + 1e-6)).alias('amount_ratio'),
    
    # === Đặc trưng thời gian chi tiết ===
    # Giờ trong ngày (0-23)
    # Rửa tiền thường xảy ra vào giờ không bình thường
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M').dt.hour().alias('hour'),
    # Ngày trong tuần (0=Thứ 2, 6=Chủ nhật)
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M').dt.weekday().alias('day_of_week'),
    
    # === Đặc trưng tuyến đường ===
    # Hash(From Bank XOR To Bank) = mã hóa tuyến chuyển tiền
    # Phát hiện các tuyến lặp lại nghi ngờ
    (pl.col('From Bank').hash() ^ pl.col('To Bank').hash()).alias('route_hash'),
    
    # === Biến phân loại (chưa mã hóa) ===
    pl.col('Receiving Currency').alias('recv_curr'),
    pl.col('Payment Currency').alias('payment_curr'),
    pl.col('Payment Format').alias('payment_format'),
])

log_with_time(f"Đã trích xuất {len(df_features.collect_schema().names())} đặc trưng", step_start)
print()

# ==================== MÃ HÓA BIẾN PHÂN LOẠI ====================
step_start = time.time()
log_with_time("BƯỚC 2.3/6: Đang mã hóa biến phân loại...")
log_with_time("   ├─ Receiving Currency → Số")
log_with_time("   ├─ Payment Currency → Số")
log_with_time("   └─ Payment Format → Số")

# Label Encoding: Chuyển chuỗi thành số
# Ví dụ: "US Dollar" -> 0, "Yuan" -> 1, "Euro" -> 2, ...
df_features = df_features.with_columns([
    pl.col('recv_curr').cast(pl.Categorical).to_physical().alias('recv_curr_encoded'),
    pl.col('payment_curr').cast(pl.Categorical).to_physical().alias('payment_curr_encoded'),
    pl.col('payment_format').cast(pl.Categorical).to_physical().alias('payment_format_encoded'),
])

log_with_time("Đã mã hóa thành số", step_start)
print()

# ==================== CHỌN ĐẶC TRƯNG SỐ ====================
step_start = time.time()
log_with_time("BƯỚC 2.4/6: Đang chọn các đặc trưng số...")
# Chỉ giữ lại 9 đặc trưng số (loại bỏ chuỗi)
df_numeric = df_features.select([
    'amount_received',      # Số tiền nhận
    'amount_paid',          # Số tiền trả
    'amount_ratio',         # Tỷ lệ
    'hour',                 # Giờ
    'day_of_week',          # Ngày trong tuần
    'route_hash',           # Mã tuyến
    'recv_curr_encoded',    # Loại tiền nhận (số)
    'payment_curr_encoded', # Loại tiền trả (số)
    'payment_format_encoded', # Hình thức thanh toán (số)
])

log_with_time(f"✅ Đã chọn {len(df_numeric.collect_schema().names())} đặc trưng số cho K-means", step_start)
feature_list = df_numeric.collect_schema().names()
for i, feat in enumerate(feature_list, 1):
    print(f"   {i}. {feat}")
print()

# ==================== CHUẨN HÓA (NORMALIZATION) ====================
step_start = time.time()
log_with_time("BƯỚC 2.5/6: Đang chuẩn hóa dữ liệu (chuẩn Z-score)...")
log_with_time("   Công thức: (x - mean) / std")
log_with_time("   Mục đích: Đưa tất cả features về cùng scale")

# Chuẩn hóa: Đưa tất cả về khoảng [0, 1]
# Công thức: (x - mean) / std
# Lý do: Các đặc trưng có scale khác nhau (tiền có thể hàng triệu, giờ chỉ 0-23)
# Nếu không chuẩn hóa, K-means sẽ bị ảnh hưởng bởi đặc trưng có giá trị lớn
df_normalized = df_numeric.select([
    ((pl.col(c) - pl.col(c).mean()) / pl.col(c).std()).alias(c)
    for c in df_numeric.collect_schema().names()
])

log_with_time(f"Đã chuẩn hóa {len(df_normalized.collect_schema().names())} đặc trưng", step_start)
print()

# ==================== LƯU FILE TẠM THỜI ====================
step_start = time.time()
log_with_time("BƯỚC 2.6/6: Đang lưu tệp tạm thời cho HDFS...")
log_with_time("Lưu ý: Tệp này sẽ tự động xóa sau khi tải lên HDFS!")

temp_output = os.path.join(DATA_PROCESSED, 'hadoop_input_temp.txt')
log_with_time(f"   Đang ghi: {temp_output}")
log_with_time("   Vui lòng đợi (có thể mất 3-5 phút)...")
log_with_time("   Polars đang ghi luồng dữ liệu xuống đĩa (không tốn RAM)")
print()

# Ghi file không có header (chỉ có số)
# Sink = streaming write (không tốn RAM)
df_normalized.sink_csv(temp_output, include_header=False)

log_with_time("Đã ghi xong tệp", step_start)

file_size_mb = os.path.getsize(temp_output) / (1024 * 1024 * 1024)

total_time = time.time() - PIPELINE_START

print()
print("="*70)
log_with_time("HOÀN TẤT XỬ LÝ DỮ LIỆU!")
print("="*70)
print()
print("THỐNG KÊ KẾT QUẢ:")
print(f"   Tệp tạm: {temp_output}")
print(f"   Kích thước: {file_size_mb:.2f} GB")
print(f"   Số dòng: [ghi luồng - không đếm]")
print(f"   Số đặc trưng: {len(df_normalized.collect_schema().names())}")
print(f"   Danh sách đặc trưng:")
for i, feat in enumerate(df_normalized.collect_schema().names(), 1):
    print(f"      {i}. {feat}")
print()
log_with_time(f"Tổng thời gian bước 2: {total_time/60:.1f} phút ({total_time:.1f}s)")
print()
print("LƯU Ý QUAN TRỌNG:")
print("   ├─ File này chỉ tồn tại TẠM THỜI!")
print("   ├─ Nó sẽ BỊ XÓA sau khi upload lên HDFS (Bước 3)")
print("   └─ Dữ liệu chỉ lưu trên HDFS để tuân thủ quy định bảo mật")
print()
print("GỢI Ý TIẾP THEO:")
print("   Chạy bước 3: bash 02_scripts/spark/setup_hdfs.sh")
print("   (MLlib sẽ tự động dùng k-means++ initialization)")
print()
