#!/usr/bin/env python3
# ==============================================================================
# File: explore_fast.py
# ==============================================================================
"""
──────────────────────────────────────────────────────────────────────────────
📊 DỰ ÁN: Phân Tích Rửa Tiền — K-means Clustering (Polars + Spark)
BƯỚC 1/7: KHÁM PHÁ DỮ LIỆU (DATA EXPLORATION)
──────────────────────────────────────────────────────────────────────────────

TÓM TẮT
- Mục tiêu: Hiểu cấu trúc CSV (179M dòng), thống kê mô tả, phân phối nhãn,
  và top loại tiền tệ.
- Công nghệ: Polars (scan_csv, lazy evaluation) — không tải toàn bộ vào RAM.

I/O & THỜI GIAN
- Input : 01_data/raw/HI-Large_Trans.csv (~16GB)
- Output: In ra màn hình (schema, sample, describe, distributions)
- Thời gian chạy: ~30 giây (tùy máy)

CÁCH CHẠY NHANH
  python 02_scripts/polars/explore_fast.py \
    --raw 01_data/raw/HI-Large_Trans.csv \
    --sample-rows 100000

THAM SỐ CLI
- --raw <path>         : Đường dẫn file CSV gốc
- --sample-rows <int>  : Số dòng mẫu để mô tả (mặc định 100000)
"""

import polars as pl
import os
import argparse

# ==================== CẤU HÌNH ĐƯỜNG DẪN ====================
# Lấy thư mục gốc của dự án (2 cấp lên từ thư mục hiện tại)
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

def parse_args():
    parser = argparse.ArgumentParser(description="Khám phá dữ liệu CSV quy mô lớn")
    parser.add_argument("--raw", type=str, default=None, help="Đường dẫn file CSV gốc")
    parser.add_argument("--sample-rows", type=int, default=100000, help="Số dòng mẫu để mô tả")
    return parser.parse_args()

args = parse_args()

# Đường dẫn đến file CSV gốc (16GB, 179M dòng)
DATA_RAW = args.raw or os.path.join(ROOT_DIR, '01_data', 'raw', 'HI-Large_Trans.csv')

print("="*70)
print("BƯỚC 1: KHÁM PHÁ DỮ LIỆU")
print("="*70)
print(f"Đang đọc file: {DATA_RAW}")
print("Vui lòng đợi...\n")

# ==================== ĐỌC DỮ LIỆU (LAZY MODE) ====================
# Lazy scan = Chỉ đọc metadata, KHÔNG load toàn bộ vào RAM
# Điều này giúp tiết kiệm bộ nhớ khi làm việc với file lớn
if not os.path.isfile(DATA_RAW):
    raise FileNotFoundError(f"Không tìm thấy file: {DATA_RAW}")

df = pl.scan_csv(DATA_RAW)

print("Đã tải metadata thành công!\n")

# ==================== XEM CẤU TRÚC DỮ LIỆU ====================
print("CẤU TRÚC DỮ LIỆU (SCHEMA):")
print("-" * 70)
print(df.collect_schema)
print()

# ==================== LẤY MẪU ĐỂ PHÂN TÍCH ====================
print(f"LẤY MẪU {args.sample_rows:,} DÒNG ĐẦU:")
print("-" * 70)

# Head = lấy n dòng đầu
# Collect = thực thi query và load vào RAM
sample = df.head(args.sample_rows).collect()

print("Dữ liệu mẫu:")
print(sample)
print()

print("Thống kê mô tả:")
print(sample.describe())
print()

# ==================== PHÂN TÍCH TỶ LỆ RỬA TIỀN ====================
print("PHÂN TÍCH TỶ LỆ RỬA TIỀN:")
print("-" * 70)

# Value_counts = đếm số lượng mỗi giá trị
# Is Laundering: 0 = Bình thường, 1 = Rửa tiền
laundering_dist = df.select(pl.col('Is Laundering').value_counts()).collect()
print(laundering_dist)
print()

# ==================== PHÂN TÍCH LOẠI TIỀN TỆ ====================
print("TOP 10 LOẠI TIỀN TỆ PHỔ BIẾN:")
print("-" * 70)

# Đếm và sắp xếp theo số lượng
currency_dist = df.select(
    pl.col('Receiving Currency').value_counts().head(10)
).collect()
print(currency_dist)
print()

print("="*70)
print("HOÀN TẤT KHÁM PHÁ DỮ LIỆU!")
print("="*70)
print("\nGỢI Ý TIẾP THEO:")
print("   Chạy bước 2: python 02_scripts/polars/prepare_polars.py")
print()


