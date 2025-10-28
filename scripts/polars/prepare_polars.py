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
Input: data/raw/HI-Large_Trans.csv (16GB, 179M dòng)
Output: data/processed/hadoop_input_temp.txt (33GB, TẠM THỜI)

⚠️  LƯU Ý: File output sẽ BỊ XÓA TỰ ĐỘNG sau khi upload lên HDFS!
"""

import polars as pl
import numpy as np
import os

# ==================== CẤU HÌNH ĐƯỜNG DẪN ====================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_RAW = os.path.join(ROOT_DIR, 'data', 'raw', 'HI-Large_Trans.csv')
DATA_PROCESSED = os.path.join(ROOT_DIR, 'data', 'processed')

# Tạo thư mục processed nếu chưa có
os.makedirs(DATA_PROCESSED, exist_ok=True)

print("="*70)
print("🔧 BƯỚC 2: XỬ LÝ VÀ TRÍCH XUẤT ĐẶC TRƯNG")
print("="*70)
print(f"Đọc file: {DATA_RAW}")
print("Vui lòng đợi (có thể mất 5-10 phút)...\n")

# ==================== ĐỌC DỮ LIỆU ====================
# Read_csv = Load toàn bộ vào RAM (cần ~20GB RAM)
# Nếu không đủ RAM, dùng scan_csv và xử lý từng batch
df = pl.read_csv(DATA_RAW)

print(f"✅ Đã load {len(df):,} dòng vào RAM\n")

# ==================== TRÍCH XUẤT ĐẶC TRƯNG ====================
print("🌟 TRÍCH XUẤT ĐẶC TRƯNG TỪ DỮ LIỆU THÔ...")

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

print(f"✅ Đã trích xuất {len(df_features.columns)} đặc trưng\n")

# ==================== MÃ HÓA BIẾN PHÂN LOẠI ====================
print("🔢 MÃ HÓA BIẾN PHÂN LOẠI (CATEGORICAL ENCODING)...")

# Label Encoding: Chuyển chuỗi thành số
# Ví dụ: "US Dollar" -> 0, "Yuan" -> 1, "Euro" -> 2, ...
df_features = df_features.with_columns([
    pl.col('recv_curr').cast(pl.Categorical).to_physical().alias('recv_curr_encoded'),
    pl.col('payment_curr').cast(pl.Categorical).to_physical().alias('payment_curr_encoded'),
    pl.col('payment_format').cast(pl.Categorical).to_physical().alias('payment_format_encoded'),
])

print("✅ Đã mã hóa thành số\n")

# ==================== CHỌ8N ĐẶC TRƯNG SỐ ====================
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

print(f"📊 Có {len(df_numeric.columns)} đặc trưng số cho K-means\n")

# ==================== CHUẨN HÓA (NORMALIZATION) ====================
print("📊 CHUẨN HÓA DỮ LIỆU (Min-Max Scaling)...")

# Chuẩn hóa: Đưa tất cả về khoảng [0, 1]
# Công thức: (x - mean) / std
# Lý do: Các đặc trưng có scale khác nhau (tiền có thể hàng triệu, giờ chỉ 0-23)
# Nếu không chuẩn hóa, K-means sẽ bị ảnh hưởng bởi đặc trưng có giá trị lớn
df_normalized = df_numeric.select([
    ((pl.col(c) - pl.col(c).mean()) / pl.col(c).std()).alias(c)
    for c in df_numeric.columns
])

print(f"✅ Đã chuẩn hóa {len(df_normalized.columns)} đặc trưng\n")

# ==================== LƯU FILE TẠM THỜI ====================
print("💾 LƯU FILE TẠM THỜI CHO HDFS...")
print("⚠️  LƯU Ý: File này sẽ tự động xóa sau khi upload HDFS!\n")

temp_output = os.path.join(DATA_PROCESSED, 'hadoop_input_temp.txt')
print(f"   Đang ghi: {temp_output}")
print("   Vui lòng đợi (có thể mất 3-5 phút)...\n")

# Ghi file không có header (chỉ có số)
df_normalized.write_csv(temp_output, include_header=False)

file_size_mb = os.path.getsize(temp_output) / (1024 * 1024 * 1024)
print("="*70)
print("✅ HOÀN TẤT XỬ LÝ DỮ LIỆU!")
print("="*70)
print(f"📄 File tạm: {temp_output}")
print(f"📊 Kích thước: {file_size_mb:.2f} GB")
print(f"📊 Số dòng: {len(df_normalized):,}")
print(f"📊 Số đặc trưng: {len(df_normalized.columns)}")
print(f"📊 Các đặc trưng: {df_normalized.columns}")
print()
print("⚠️  QUAN TRỌNG:")
print("   File này chỉ tồn tại TẠM THỜI!")
print("   Nó sẽ BỊ XÓA sau khi upload lên HDFS (Bước 4)")
print("   Dữ liệu chỉ lưu trên HDFS để tuân thủ quy định bảo mật")
print()
print("💡 GỢI Ý TIẾP THEO:")
print("   Chạy bước 3: python scripts/polars/init_centroids.py")
print()
