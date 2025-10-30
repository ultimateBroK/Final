#!/usr/bin/env python3
# ==============================================================================
# File: 05_analyze.py
# ==============================================================================
"""
──────────────────────────────────────────────────────────────────────────────
📊 DỰ ÁN: Phân Tích Rửa Tiền — K-means Clustering (Polars + Spark)
BƯỚC 7/7: PHÂN TÍCH KẾT QUẢ (CLUSTER ANALYSIS)
──────────────────────────────────────────────────────────────────────────────

TÓM TẮT
- Mục tiêu: Tính kích thước cụm, tỷ lệ rửa tiền theo cụm, đặc trưng trung bình,
  đánh giá rủi ro và (nếu có) xuất danh sách giao dịch nghi ngờ.
- Công nghệ: Polars (scan_csv, lazy evaluation) — gắn nhãn cụm rồi tổng hợp.

I/O & THỜI GIAN
- Input : 01_data/results/clustered_results.txt (labels từ bước 6)
- Input : 01_data/raw/HI-Large_Trans.csv (dữ liệu gốc)
- Output: In báo cáo + 01_data/results/suspicious_transactions.csv (nếu có)
- Thời gian chạy: ~2 phút (tùy máy)

CÁCH CHẠY NHANH
  python 02_scripts/polars/05_analyze.py

GHI CHÚ
- Xác định cụm rủi ro cao theo ngưỡng > 10% rửa tiền.
- Tất cả phép tính thực hiện sau khi gắn cột `cluster` vào dữ liệu gốc.
"""

import polars as pl
import numpy as np
import os
import gc

# ==================== CẤU HÌNH ĐƯỜNG DẪN ====================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_RAW = os.path.join(ROOT_DIR, '01_data', 'raw', 'HI-Large_Trans.csv')
DATA_RESULTS = os.path.join(ROOT_DIR, '01_data', 'results')

print("="*70)
print("📊 BƯỚC 7: PHÂN TÍCH KẾT QUẢ")
print("="*70)
print()

# ==================== ĐỌC KẾT QUẢ PHÂN CỤM ====================
print("📂 ĐỌC KẾT QUẢ PHÂN CỤM TỪ BƯỚC 6...")

clusters_file = os.path.join(DATA_RESULTS, 'clustered_results.txt')
print(f"   File: {clusters_file}")

# Đọc mảng cluster IDs (mỗi dòng = 1 số 0-4)
clusters = np.loadtxt(clusters_file, dtype=int)
print(f"✅ Đã load {len(clusters):,} nhãn cụm\n")

# ==================== ĐỌC DỮ LIỆU GỐC ====================
print("📊 ĐỌC DỮ LIỆU GỐC (Lazy Mode)...")
print(f"   File: {DATA_RAW}")

# Dùng scan_csv (lazy) thay vì read_csv để tiết kiệm RAM
# Chỉ thực thi khi gọi .collect()
df_lazy = pl.scan_csv(DATA_RAW)

print("✅ Đã load metadata (chưa load toàn bộ vào RAM)\n")

# ==================== GẮN NHÃN CỤM VÀO DATA ====================
print("🎯 THÊM CỘT 'cluster' VÀO DATA...")

# Thêm cột cluster vào DataFrame (vẫn lazy)
df_result = df_lazy.with_columns(
    pl.Series('cluster', clusters).alias('cluster')
)

print("✅ Đã gắn nhãn cụm cho mỗi giao dịch\n")

print("="*70)
print("📋 PHÂN TÍCH CHI TIẾT")
print("="*70)
print()

# ==================== THỐNG KÊ TỔNG QUAN ====================
print("📈 THỐNG KÊ TỔNG QUAN:")
print(f"   Tổng số giao dịch: {len(clusters):,}")
print(f"   Số cụm: {np.unique(clusters).size}")
print()

# ==================== KÍCH THƯỚC CỤM ====================
print("📉 KÍCH THƯỚC MỖI CỤM:")
print("-" * 70)

# Đếm số lượng giao dịch trong mỗi cụm
cluster_counts = df_result.group_by('cluster').agg(
    pl.len().alias('count')
).sort('cluster').collect()  # Collect = thực thi query

print(cluster_counts)
print()

# ==================== PHÂN TÍCH TỶ LỆ RỬA TIỀN ====================
print("💰 TỶ LỆ RỬA TIỀN TRONG TỮNG CỤM:")
print("-" * 70)

# Tính tỷ lệ rửa tiền cho mỗi cụm
laundering_stats = df_result.group_by('cluster').agg([
    pl.len().alias('total'),  # Tổng số giao dịch
    pl.col('Is Laundering').sum().alias('laundering_count'),  # Số giao dịch rửa tiền
    (pl.col('Is Laundering').sum() / pl.len() * 100).alias('laundering_rate')  # % rửa tiền
]).sort('cluster').collect()

print(laundering_stats)
print()

# Giải phóng bộ nhớ
gc.collect()

# ==================== XÁC ĐịNH CỤM RỦI RO CAO ====================
print("⚠️  CỤM CÓ RỦI RO CAO (>10% rửa tiền):")
print("-" * 70)

# Lọc các cụm có tỷ lệ rửa tiền > 10%
high_risk = laundering_stats.filter(pl.col('laundering_rate') > 10.0)

if len(high_risk) > 0:
    print(high_risk)
    print()
    print("⚠️  CẢNH BÁO: Có cụm rủi ro cao! Cần kiểm tra kỹ!")
else:
    print("✅ KHÔNG có cụm nào vượt ngưỡng 10%")
    print("   Tất cả các cụm đều trong mức chấp nhận được.")
print()

# ==================== PHÂN TÍCH ĐẶC TRƯNG TRUNG BÌNH ====================
print("📊 ĐẶC TRƯNG TRUNG BÌNH MỖI CỤM:")
print("-" * 70)

# Tính giá trị trung bình các đặc trưng cho mỗi cụm
feature_stats = df_result.group_by('cluster').agg([
    pl.col('Amount Received').mean().alias('avg_amount_received'),  # TB tiền nhận
    pl.col('Amount Paid').mean().alias('avg_amount_paid'),  # TB tiền trả
    (pl.col('Amount Received') / pl.col('Amount Paid')).mean().alias('avg_ratio'),  # TB tỷ lệ
]).sort('cluster').collect()

print(feature_stats)
print()

# Giải phóng bộ nhớ
gc.collect()

# ==================== NHẬN XÉT ====================
print("💡 NHẬN XÉT:")
print("-" * 70)

# Tìm cụm có tỷ lệ rửa tiền cao nhất và thấp nhất
max_rate = laundering_stats['laundering_rate'].max()
min_rate = laundering_stats['laundering_rate'].min()

max_cluster = laundering_stats.filter(
    pl.col('laundering_rate') == max_rate
)['cluster'][0]

min_cluster = laundering_stats.filter(
    pl.col('laundering_rate') == min_rate
)['cluster'][0]

print(f"1. CỤm nghi ngờ NHẤT: Cluster {max_cluster} ({max_rate:.2f}% rửa tiền)")
print(f"   ➡️  Nên kiểm tra kỹ các giao dịch trong cụm này")
print()
print(f"2. Cụm an toàn NHẤT: Cluster {min_cluster} ({min_rate:.2f}% rửa tiền)")
print(f"   ➡️  Có thể ưu tiên thấp khi kiểm tra")
print()

# Đánh giá tổng thể
if max_rate > 10.0:
    print("3. Đánh giá tổng thể: ⚠️  CÓ RỦI RO")
    print("   Có cụm vượt ngưỡng 10% - cần hành động ngay")
elif max_rate > 1.0:
    print("3. Đánh giá tổng thể: ⚠️  RỦI RO TRUNG BÌNH")
    print("   Tỷ lệ rửa tiền trong mức chấp nhận nhưng cần theo dõi")
else:
    print("3. Đánh giá tổng thể: ✅ RỦI RO THẤP")
    print("   Hệ thống hoạt động tốt, tỷ lệ rửa tiền thấp")
print()

# ==================== XUẤT GIAO DỊCH NGHI NGờ ====================
if len(high_risk) > 0:
    print("="*70)
    print("📤 XUẤT GIAO DỊCH NGHI NGờ")
    print("="*70)
    
    high_risk_ids = high_risk['cluster'].to_list()
    print(f"Các cụm rủi ro cao: {high_risk_ids}")
    print("\nĐang xuất giao dịch...")
    
    # Lọc các giao dịch thuộc cụm rủi ro cao
    suspicious = df_result.filter(
        pl.col('cluster').is_in(high_risk_ids)
    ).collect()
    
    suspicious_path = os.path.join(DATA_RESULTS, 'suspicious_transactions.csv')
    suspicious.write_csv(suspicious_path)
    
    print(f"\n✅ Đã lưu {len(suspicious):,} giao dịch nghi ngờ")
    print(f"   File: {suspicious_path}")
    print()
    print("💡 Bước tiếp theo:")
    print("   - Xem file suspicious_transactions.csv")
    print("   - Kiểm tra thủ công các giao dịch này")
    print("   - Báo cáo cho cơ quan chức năng nếu cần")
    print()
    
    # Giải phóng bộ nhớ
    del suspicious
    gc.collect()

print("="*70)
print("✅ HOÀN TẤT PHÂN TÍCH!")
print("="*70)
print()
print("📊 TÓM TẢT:")
print(f"   - Đã phân tích {len(clusters):,} giao dịch")
print(f"   - Phân thành {np.unique(clusters).size} cụm")
print(f"   - Tỷ lệ rửa tiền: {min_rate:.2f}% - {max_rate:.2f}%")
if len(high_risk) > 0:
    print(f"   - Số cụm rủi ro cao: {len(high_risk)}")
else:
    print(f"   - Số cụm rủi ro cao: 0 (✅ Tốt!)")
print()
print("🎉 PIPELINE HOÀN TẤT!")
print("   Tất cả 7 bước đã chạy thành công.")
print("   Xem kết quả trong thư mục 01_data/results/")
print()
