#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VISUALIZATION SCRIPT: Trực quan hóa kết quả clustering

Mục đích:
- Tạo biểu đồ phân tích kết quả K-means
- Hiển thị phân phối clusters, tỷ lệ rửa tiền
- Lưu các biểu đồ vào folder 06_visualizations

Sử dụng:
    python 02_scripts/data/visualize_results.py
"""

import os
import numpy as np
import polars as pl
from datetime import datetime

# ==================== CẤU HÌNH ====================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_RAW = os.path.join(ROOT_DIR, '01_data', 'raw', 'HI-Large_Trans.csv')
DATA_RESULTS = os.path.join(ROOT_DIR, '01_data', 'results')
VISUALIZATIONS_DIR = os.path.join(ROOT_DIR, '06_visualizations')

# Tạo thư mục visualizations
os.makedirs(VISUALIZATIONS_DIR, exist_ok=True)

def create_visualizations():
    """Tạo các biểu đồ trực quan"""
    
    print("="*70)
    print("📊 TẠO BIỂU ĐỒ TRỰC QUAN")
    print("="*70)
    print()
    
    # ==================== ĐỌC DỮ LIỆU ====================
    print("📂 Đọc dữ liệu...")
    
    clusters_file = os.path.join(DATA_RESULTS, 'clustered_results.txt')
    clusters = np.loadtxt(clusters_file, dtype=int)
    
    print(f"✅ Đã load {len(clusters):,} nhãn cụm")
    
    # Đọc dữ liệu gốc (chỉ cột Is Laundering)
    df_lazy = pl.scan_csv(DATA_RAW).select(['Is Laundering'])
    df = df_lazy.with_columns(
        pl.Series('cluster', clusters).alias('cluster')
    ).collect()
    
    print("✅ Đã load dữ liệu gốc")
    print()
    
    # ==================== PHÂN TÍCH DỮ LIỆU ====================
    print("🔍 Phân tích dữ liệu...")
    
    # Kích thước clusters
    cluster_counts = df.group_by('cluster').agg(
        pl.len().alias('count')
    ).sort('cluster')
    
    # Tỷ lệ rửa tiền
    laundering_stats = df.group_by('cluster').agg([
        pl.len().alias('total'),
        pl.col('Is Laundering').sum().alias('laundering_count'),
        (pl.col('Is Laundering').sum() / pl.len() * 100).alias('laundering_rate')
    ]).sort('cluster')
    
    print("✅ Hoàn tất phân tích")
    print()
    
    # ==================== TẠO ASCII CHARTS ====================
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_file = os.path.join(VISUALIZATIONS_DIR, f'visual_report_{timestamp}.md')
    
    print(f"📝 Tạo báo cáo trực quan: {report_file}")
    
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("# BÁO CÁO TRỰC QUAN KẾT QUẢ CLUSTERING\n\n")
        f.write(f"**Thời gian:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"**Tổng giao dịch:** {len(clusters):,}\n\n")
        f.write("---\n\n")
        
        # ==================== BIỂU ĐỒ 1: PHÂN PHỐI CLUSTERS ====================
        f.write("## 1. PHÂN PHỐI CÁC CỤM\n\n")
        f.write("Biểu đồ cột hiển thị số lượng giao dịch trong mỗi cụm:\n\n")
        f.write("```\n")
        
        max_count = cluster_counts['count'].max()
        max_bar_length = 50
        
        for row in cluster_counts.iter_rows(named=True):
            cluster_id = row['cluster']
            count = row['count']
            percentage = (count / len(clusters)) * 100
            bar_length = int((count / max_count) * max_bar_length)
            bar = '█' * bar_length
            
            f.write(f"Cluster {cluster_id} │{bar:50s}│ {count:>12,} ({percentage:5.2f}%)\n")
        
        f.write("```\n\n")
        
        # ==================== BIỂU ĐỒ 2: TỶ LỆ RỬA TIỀN ====================
        f.write("## 2. TỶ LỆ RỬA TIỀN THEO CỤM\n\n")
        f.write("Biểu đồ cột ngang hiển thị tỷ lệ % rửa tiền:\n\n")
        f.write("```\n")
        
        max_rate = laundering_stats['laundering_rate'].max()
        max_bar_length = 40
        
        for row in laundering_stats.iter_rows(named=True):
            cluster_id = row['cluster']
            rate = row['laundering_rate']
            laundering_count = row['laundering_count']
            
            # Tính độ dài thanh dựa trên tỷ lệ
            if max_rate > 0:
                bar_length = int((rate / max_rate) * max_bar_length)
            else:
                bar_length = 0
            
            # Màu cảnh báo (ASCII)
            if rate > 10.0:
                marker = '🔴'
                level = 'RỦI RO CAO'
            elif rate > 1.0:
                marker = '🟡'
                level = 'RỦI RO TB'
            else:
                marker = '🟢'
                level = 'AN TOÀN'
            
            bar = '▓' * bar_length
            
            f.write(f"Cluster {cluster_id} {marker} │{bar:40s}│ {rate:6.3f}% ({laundering_count:>8,}) - {level}\n")
        
        f.write("```\n\n")
        
        # ==================== BẢNG THỐNG KÊ CHI TIẾT ====================
        f.write("## 3. BẢNG THỐNG KÊ CHI TIẾT\n\n")
        f.write("| Cluster | Tổng giao dịch | Rửa tiền | Tỷ lệ (%) | Phân loại |\n")
        f.write("|---------|----------------|----------|-----------|------------|\n")
        
        for row in laundering_stats.iter_rows(named=True):
            cluster_id = row['cluster']
            total = row['total']
            laundering = row['laundering_count']
            rate = row['laundering_rate']
            
            if rate > 10.0:
                risk = '⚠️ RỦI RO CAO'
            elif rate > 1.0:
                risk = '⚠️ Trung bình'
            else:
                risk = '✅ Thấp'
            
            f.write(f"| {cluster_id} | {total:,} | {laundering:,} | {rate:.3f} | {risk} |\n")
        
        f.write("\n")
        
        # ==================== NHẬN XÉT ====================
        f.write("## 4. NHẬN XÉT VÀ KHUYẾN NGHỊ\n\n")
        
        max_rate_val = laundering_stats['laundering_rate'].max()
        min_rate_val = laundering_stats['laundering_rate'].min()
        
        max_cluster_row = laundering_stats.filter(
            pl.col('laundering_rate') == max_rate_val
        ).row(0, named=True)
        
        min_cluster_row = laundering_stats.filter(
            pl.col('laundering_rate') == min_rate_val
        ).row(0, named=True)
        
        f.write(f"### Cụm nghi ngờ nhất\n")
        f.write(f"- **Cluster {max_cluster_row['cluster']}**: {max_rate_val:.3f}% rửa tiền\n")
        f.write(f"- Số giao dịch rửa tiền: {max_cluster_row['laundering_count']:,}\n")
        f.write(f"- 🎯 **Khuyến nghị**: Ưu tiên kiểm tra cụm này\n\n")
        
        f.write(f"### Cụm an toàn nhất\n")
        f.write(f"- **Cluster {min_cluster_row['cluster']}**: {min_rate_val:.3f}% rửa tiền\n")
        f.write(f"- Số giao dịch rửa tiền: {min_cluster_row['laundering_count']:,}\n")
        f.write(f"- ✅ **Khuyến nghị**: Ưu tiên thấp\n\n")
        
        # Đánh giá tổng thể
        f.write("### Đánh giá tổng thể\n\n")
        if max_rate_val > 10.0:
            f.write("⚠️ **CÓ RỦI RO CAO**\n\n")
            f.write("Có cụm vượt ngưỡng 10% rửa tiền. Cần hành động ngay:\n")
            f.write("- Kiểm tra chi tiết các giao dịch trong cụm rủi ro cao\n")
            f.write("- Xem xét tăng cường giám sát\n")
            f.write("- Báo cáo cơ quan chức năng nếu cần\n")
        elif max_rate_val > 1.0:
            f.write("⚠️ **RỦI RO TRUNG BÌNH**\n\n")
            f.write("Tỷ lệ rửa tiền trong mức chấp nhận nhưng cần theo dõi:\n")
            f.write("- Theo dõi xu hướng theo thời gian\n")
            f.write("- Xem xét điều chỉnh threshold phát hiện\n")
        else:
            f.write("✅ **RỦI RO THẤP**\n\n")
            f.write("Hệ thống hoạt động tốt:\n")
            f.write("- Tỷ lệ rửa tiền thấp trên tất cả các cụm\n")
            f.write("- Tiếp tục duy trì giám sát định kỳ\n")
        
        f.write("\n---\n\n")
        f.write("**Ghi chú**: Biểu đồ được tạo bằng ký tự ASCII để dễ xem trên terminal và text editor.\n")
    
    print(f"✅ Đã lưu báo cáo: {report_file}")
    print()
    
    # ==================== TẠO SUMMARY TXT ====================
    summary_file = os.path.join(VISUALIZATIONS_DIR, 'latest_summary.txt')
    
    with open(summary_file, 'w', encoding='utf-8') as f:
        f.write("TÓM TẮT KẾT QUẢ CLUSTERING\n")
        f.write("="*50 + "\n\n")
        f.write(f"Thời gian: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Tổng giao dịch: {len(clusters):,}\n")
        f.write(f"Số cụm: {len(cluster_counts)}\n\n")
        
        f.write("PHÂN PHỐI:\n")
        for row in cluster_counts.iter_rows(named=True):
            percentage = (row['count'] / len(clusters)) * 100
            f.write(f"  Cluster {row['cluster']}: {row['count']:,} ({percentage:.2f}%)\n")
        
        f.write("\nTỶ LỆ RỬA TIỀN:\n")
        for row in laundering_stats.iter_rows(named=True):
            f.write(f"  Cluster {row['cluster']}: {row['laundering_rate']:.3f}% ({row['laundering_count']:,} giao dịch)\n")
    
    print(f"✅ Đã lưu summary: {summary_file}")
    print()
    
    # ==================== HOÀN TẤT ====================
    print("="*70)
    print("✅ HOÀN TẤT TẠO BIỂU ĐỒ!")
    print("="*70)
    print(f"📁 Thư mục: {VISUALIZATIONS_DIR}")
    print(f"📊 Báo cáo chi tiết: {os.path.basename(report_file)}")
    print(f"📄 Tóm tắt: latest_summary.txt")
    print()
    print("💡 Xem báo cáo:")
    print(f"   cat {report_file}")
    print(f"   cat {summary_file}")
    print()

if __name__ == "__main__":
    create_visualizations()
