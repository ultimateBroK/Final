#!/usr/bin/env python3
# ==============================================================================
# File: assign_clusters_polars.py
# ==============================================================================
"""
──────────────────────────────────────────────────────────────────────────────
📊 DỰ ÁN: Phân Tích Rửa Tiền — K-means Clustering (Polars + Spark)
BƯỚC 6/7: GÁN NHÃN CỤM CHO TỪNG GIAO DỊCH
──────────────────────────────────────────────────────────────────────────────

TÓM TẮT
- Mục tiêu: Tính khoảng cách Euclidean tới các tâm cụm cuối cùng và gán nhãn
  cụm (0..K-1) cho từng giao dịch theo batch để tiết kiệm RAM.
- Công nghệ: Polars (đọc stream từ HDFS) + NumPy (vectorized distance).

I/O & THỜI GIAN
- Input : data/results/final_centroids.txt (centroids tải từ HDFS)
- Input : HDFS /user/spark/hi_large/input/hadoop_input.txt (179M dòng)
- Output: data/results/clustered_results.txt (ID cụm mỗi giao dịch)
- Thời gian chạy: ~10 phút (tùy máy)

CÁCH CHẠY NHANH
  python scripts/polars/assign_clusters_polars.py \
    --centroids data/results/final_centroids.txt \
    --hdfs-path /user/spark/hi_large/input/hadoop_input.txt

THAM SỐ CLI
- --centroids <path> : Đường dẫn file tâm cụm (mặc định data/results/final_centroids.txt)
- --hdfs-path <path> : Đường dẫn HDFS tới hadoop_input.txt

GHI CHÚ
- Xử lý theo batch 1,000,000 bản ghi/lượt để ổn định bộ nhớ.
"""

import polars as pl
import numpy as np
import os
import subprocess
import argparse

# ==================== CẤU HÌNH ĐƯỜNG DẪN ====================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_PROCESSED = os.path.join(ROOT_DIR, 'data', 'processed')
DATA_RESULTS = os.path.join(ROOT_DIR, 'data', 'results')

# Tạo thư mục results nếu chưa có
os.makedirs(DATA_RESULTS, exist_ok=True)

print("="*70)
print("🏷️  BƯỚC 6: GÁN NHÃN CỤM CHO TỪNG GIAO DỊCH")
print("="*70)
print()

# ==================== ĐỌC TÂM CỤM CUỐI CÙNG ====================
print("🎯 ĐỌC TÂM CỤM CUỐI CÙNG TỪ BƯỚC 5...")

centroids_file = os.path.join(DATA_RESULTS, 'final_centroids.txt')
print(f"   File: {centroids_file}")

try:
    # Load tập tin chứa 5 tâm cụm (mỗi dòng = 1 tâm cụm với 9 giá trị)
    centroids = np.loadtxt(centroids_file, delimiter=',')
    
    # Nếu chỉ có 1 tâm cụm, reshape thành matrix 1x9
    if centroids.ndim == 1:
        centroids = centroids.reshape(1, -1)
    
    # Kiểm tra file rỗng
    if centroids.size == 0:
        raise ValueError("File tâm cụm rỗng!")
    
    print(f"\n✅ Đã load {centroids.shape[0]} tâm cụm")
    print(f"   Mỗi tâm cụm có {centroids.shape[1]} đặc trưng")
    print()
    
except (ValueError, OSError) as e:
    print(f"\n❌ LỐI: Không đọc được file tâm cụm!")
    print(f"   Chi tiết: {e}")
    print(f"   Đường dẫn: {centroids_file}")
    print()
    print("💡 HƯỚNG DẪN:")
    print("   1. Chạy bước 6 trước:")
    print("      ./scripts/spark/download_from_hdfs.sh")
    print("   2. Rồi chạy lại script này")
    print()
    exit(1)

# ==================== ĐỌC DỮ LIỆU TỪ HDFS ====================
print("📂 ĐỌC DỮ LIỆU TỪ HDFS...")
print("   File HDFS: /user/spark/hi_large/input/hadoop_input.txt")
print("   (179M dòng, 33GB - đã chuẩn hóa)\n")

# Streaming từ HDFS và đọc trực tiếp bằng Polars
try:
    print("🔄 Streaming từ HDFS (có thể mất vài phút)...")
    
    # Dùng hdfs dfs -cat để stream dữ liệu
    # Giống như cat file nhưng từ HDFS
    process = subprocess.Popen(
        ["hdfs", "dfs", "-cat", "/user/spark/hi_large/input/hadoop_input.txt"],
        stdout=subprocess.PIPE,  # Lấy output
        stderr=subprocess.PIPE,  # Lấy error messages
    )
    
    # Đọc trực tiếp từ stream (không cần lưu file tạm)
    print("📊 Đang đọc CSV từ HDFS stream...")
    stdout = process.stdout
    
    if stdout is None:
        raise Exception("HDFS process không có stdout stream")
    
    # Polars đọc trực tiếp từ stream
    # has_header=False vì file chỉ chứa số
    df = pl.read_csv(
        stdout,
        has_header=False,
        new_columns=[f'f{i}' for i in range(9)]  # 9 đặc trưng
    )
    
    # Đợi process hoàn thành
    returncode = process.wait()
    
    if returncode != 0:
        # Nếu có lỗi, đọc stderr
        stderr_data = process.stderr.read().decode() if process.stderr is not None else ""
        raise Exception(f"HDFS read thất bại với code {returncode}: {stderr_data}")
    
    print(f"\n✅ Đã load {len(df):,} bản ghi từ HDFS")
    print()
    
except Exception as e:
    print(f"\n❌ LỐI: Không đọc được dữ liệu từ HDFS!")
    print(f"   Chi tiết: {e}")
    print()
    print("💡 HƯỚNG DẪN:")
    print("   1. Kiểm tra HDFS đang chạy:")
    print("      hdfs dfsadmin -report")
    print("   2. Kiểm tra file tồn tại:")
    print("      hdfs dfs -ls /user/spark/hi_large/input/")
    print("   3. Nếu không có, chạy lại bước 4:")
    print("      ./scripts/spark/setup_hdfs.sh")
    print()
    exit(1)

# ==================== TÍNH TOÁN KHOẢNG CÁCH VÀ GÁN CỤM ====================
print("📊 CHUYỂN SANG NUMPY VÀ TÍNH KHOẢNG CÁCH...")

# Chuyển Polars DataFrame sang NumPy array để tính toán nhanh hơn
data = df.to_numpy()

print(f"   Dữ liệu: {data.shape[0]:,} dòng x {data.shape[1]} cột")
print(f"   Tâm cụm: {centroids.shape[0]} cụm x {centroids.shape[1]} đặc trưng")
print()

print("🔢 TÍNH KHOẢNG CÁCH EUCLIDEAN (Batch Processing)...")
print("   Xử lý 1 triệu giao dịch mỗi lần để tiết kiệm RAM\n")

# Kích thước batch (số dòng xử lý cùng lúc)
chunk_size = 1000000  # 1M giao dịch/batch

# Mảng chứa kết quả: mỗi giao dịch thuộc cụm nào (0-4)
clusters = np.zeros(len(data), dtype=np.int32)

# Xử lý từng batch
for i in range(0, len(data), chunk_size):
    end_idx = min(i + chunk_size, len(data))
    chunk = data[i:end_idx]  # Lấy 1M dòng
    
    # Tính khoảng cách Euclidean: sqrt(sum((x - y)^2))
    # chunk[:, None, :] = (batch_size, 1, 9)
    # centroids[None, :, :] = (1, 5, 9)
    # Kết quả: (batch_size, 5) = khoảng cách đến 5 tâm cụm
    distances = np.sqrt(((chunk[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2))
    
    # Chọn cụm có khoảng cách nhỏ nhất
    clusters[i:end_idx] = np.argmin(distances, axis=1)
    
    # In tiến độ mỗi 10 batch
    if (i // chunk_size) % 10 == 0 or end_idx == len(data):
        percent = (end_idx / len(data)) * 100
        print(f"    Đã xử lý {end_idx:,}/{len(data):,} giao dịch ({percent:.1f}%)")

print(f"\n✅ Đã hoàn thành tính toán cho {len(data):,} giao dịch\n")

# ==================== LƯU KẾT QUẢ ====================
print("💾 LƯU KẾT QUẢ...")

output_file = os.path.join(DATA_RESULTS, 'clustered_results.txt')
print(f"   File: {output_file}")

# Lưu mảng clusters vào file (mỗi dòng = 1 cluster ID)
np.savetxt(output_file, clusters, fmt='%d')

# Thống kê phân phối
cluster_counts = np.bincount(clusters)

file_size_mb = os.path.getsize(output_file) / (1024 * 1024)
print("="*70)
print("✅ HOÀN TẤT GÁN NHÃN CỤM!")
print("="*70)
print(f"📄 File kết quả: {output_file}")
print(f"📊 Kích thước: {file_size_mb:.2f} MB")
print(f"📊 Tổng giao dịch: {len(clusters):,}")
print()
print("📊 PHÂN PHỐI CỤM:")
for cluster_id, count in enumerate(cluster_counts):
    percent = (count / len(clusters)) * 100
    print(f"   Cluster {cluster_id}: {count:,} giao dịch ({percent:.2f}%)")
print()
print("💡 GỢI Ý TIẾP THEO:")
print("   Chạy bước 7: python scripts/polars/analyze.py")
print()


