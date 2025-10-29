#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SNAPSHOT SCRIPT: Lưu kết quả pipeline thành công

Mục đích:
- Tự động snapshot kết quả mỗi lần pipeline chạy thành công
- Lưu với timestamp để theo dõi lịch sử
- Bao gồm: centroids, clusters, logs, và metadata

Sử dụng:
    python 02_scripts/data/snapshot_results.py
"""

import os
import shutil
from datetime import datetime
import json

# ==================== CẤU HÌNH ====================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RESULTS_DIR = os.path.join(ROOT_DIR, '01_data', 'results')
SNAPSHOTS_DIR = os.path.join(ROOT_DIR, '05_snapshots')
LOGS_DIR = os.path.join(ROOT_DIR, '04_logs')

def create_snapshot():
    """Tạo snapshot của kết quả hiện tại"""
    
    # Tạo timestamp cho snapshot
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    snapshot_name = f"snapshot_{timestamp}"
    snapshot_path = os.path.join(SNAPSHOTS_DIR, snapshot_name)
    
    print("="*70)
    print(f"📸 TẠO SNAPSHOT: {snapshot_name}")
    print("="*70)
    print()
    
    # Tạo thư mục snapshot
    os.makedirs(snapshot_path, exist_ok=True)
    
    # ==================== Copy results ====================
    print("📂 Đang copy kết quả...")
    
    files_to_snapshot = [
        ('01_data/results/final_centroids.txt', 'final_centroids.txt'),
        ('01_data/results/clustered_results.txt', 'clustered_results.txt'),
    ]
    
    # Copy suspicious transactions nếu có
    suspicious_file = os.path.join(RESULTS_DIR, 'suspicious_transactions.csv')
    if os.path.exists(suspicious_file):
        files_to_snapshot.append(
            ('01_data/results/suspicious_transactions.csv', 'suspicious_transactions.csv')
        )
    
    copied_files = []
    for src_rel, dst_name in files_to_snapshot:
        src = os.path.join(ROOT_DIR, src_rel)
        dst = os.path.join(snapshot_path, dst_name)
        
        if os.path.exists(src):
            shutil.copy2(src, dst)
            file_size = os.path.getsize(src)
            copied_files.append({
                'name': dst_name,
                'size_bytes': file_size,
                'size_mb': round(file_size / (1024 * 1024), 2)
            })
            print(f"   ✅ {dst_name}")
        else:
            print(f"   ⚠️  Không tìm thấy: {src_rel}")
    
    print()
    
    # ==================== Copy latest log ====================
    print("📝 Đang copy log mới nhất...")
    
    log_files = sorted([f for f in os.listdir(LOGS_DIR) if f.startswith('pipeline_log_')])
    if log_files:
        latest_log = log_files[-1]
        src_log = os.path.join(LOGS_DIR, latest_log)
        dst_log = os.path.join(snapshot_path, 'pipeline_log.md')
        shutil.copy2(src_log, dst_log)
        print(f"   ✅ {latest_log}")
    else:
        print("   ⚠️  Không tìm thấy log files")
    
    print()
    
    # ==================== Tạo metadata ====================
    print("📋 Tạo metadata...")
    
    metadata = {
        'snapshot_name': snapshot_name,
        'timestamp': timestamp,
        'datetime': datetime.now().isoformat(),
        'files': copied_files,
        'total_size_mb': sum(f['size_mb'] for f in copied_files)
    }
    
    metadata_path = os.path.join(snapshot_path, 'metadata.json')
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    print(f"   ✅ metadata.json")
    print()
    
    # ==================== Tóm tắt ====================
    print("="*70)
    print("✅ SNAPSHOT HOÀN TẤT!")
    print("="*70)
    print(f"📁 Thư mục: {snapshot_path}")
    print(f"📊 Số files: {len(copied_files) + 2}")  # +2 for log and metadata
    print(f"💾 Tổng dung lượng: {metadata['total_size_mb']:.2f} MB")
    print()
    print("💡 Xem snapshot:")
    print(f"   cd {snapshot_path}")
    print(f"   ls -lh")
    print()
    
    return snapshot_path

def list_snapshots():
    """Liệt kê tất cả snapshots"""
    
    if not os.path.exists(SNAPSHOTS_DIR):
        print("⚠️  Chưa có snapshot nào")
        return
    
    snapshots = sorted([d for d in os.listdir(SNAPSHOTS_DIR) 
                       if os.path.isdir(os.path.join(SNAPSHOTS_DIR, d))])
    
    if not snapshots:
        print("⚠️  Chưa có snapshot nào")
        return
    
    print("="*70)
    print(f"📸 DANH SÁCH SNAPSHOTS ({len(snapshots)} snapshots)")
    print("="*70)
    print()
    
    for snapshot in snapshots:
        snapshot_path = os.path.join(SNAPSHOTS_DIR, snapshot)
        metadata_path = os.path.join(snapshot_path, 'metadata.json')
        
        if os.path.exists(metadata_path):
            with open(metadata_path, 'r', encoding='utf-8') as f:
                metadata = json.load(f)
            
            print(f"📁 {snapshot}")
            print(f"   Thời gian: {metadata['datetime']}")
            print(f"   Số files: {len(metadata['files']) + 2}")
            print(f"   Dung lượng: {metadata['total_size_mb']:.2f} MB")
            print()
        else:
            print(f"📁 {snapshot} (không có metadata)")
            print()

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == '--list':
        list_snapshots()
    else:
        create_snapshot()
