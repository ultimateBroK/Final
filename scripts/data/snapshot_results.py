#!/usr/bin/env python3
# ==============================================================================
# File: snapshot_results.py
# ==============================================================================
"""
SNAPSHOT SCRIPT: Lưu kết quả pipeline thành công

Mục đích:
- Tự động snapshot kết quả mỗi lần pipeline chạy thành công
- Lưu với timestamp để theo dõi lịch sử
- Bao gồm: centroids, clusters, logs, và metadata

Sử dụng cơ bản:
    python scripts/data/snapshot_results.py

Tham số CLI (tiếng Việt):
- --list: Liệt kê tất cả snapshots có sẵn
- --name <ten_tuy_chon>: Đặt tên snapshot tùy chọn (mặc định dùng timestamp)
- --extra <path1> [<path2> ...]: Thêm file bổ sung vào snapshot (đường dẫn tuyệt đối hoặc tương đối tính từ root dự án)
"""

import os
import shutil
from datetime import datetime
import json
import argparse
from typing import List, Dict, Any

# ==================== CẤU HÌNH ====================
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RESULTS_DIR = os.path.join(ROOT_DIR, 'data', 'results')
SNAPSHOTS_DIR = os.path.join(ROOT_DIR, 'snapshots')
LOGS_DIR = os.path.join(ROOT_DIR, 'logs')

def create_snapshot(snapshot_name: str | None = None, extra_paths: List[str] | None = None) -> str:
    """Tạo snapshot của kết quả hiện tại.

    Tham số:
    - snapshot_name: Tên thư mục snapshot (nếu None sẽ tạo theo timestamp)
    - extra_paths: Danh sách file bổ sung cần copy vào snapshot

    Trả về:
    - Đường dẫn tuyệt đối tới thư mục snapshot vừa tạo
    """

    # Tạo timestamp cho snapshot nếu chưa cung cấp tên
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    snapshot_name = snapshot_name or f"snapshot_{timestamp}"
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
        ('data/results/final_centroids.txt', 'final_centroids.txt'),
        ('data/results/clustered_results.txt', 'clustered_results.txt'),
    ]
    
    # Copy suspicious transactions nếu có
    suspicious_file = os.path.join(RESULTS_DIR, 'suspicious_transactions.csv')
    if os.path.exists(suspicious_file):
        files_to_snapshot.append(
            ('data/results/suspicious_transactions.csv', 'suspicious_transactions.csv')
        )
    
    copied_files: List[Dict[str, Any]] = []
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

    # ==================== Copy EXTRA FILES (nếu có) ====================
    if extra_paths:
        print("➕ Đang thêm file bổ sung...")
        for p in extra_paths:
            # Hỗ trợ cả đường dẫn tuyệt đối và tương đối tính từ ROOT_DIR
            abs_src = p if os.path.isabs(p) else os.path.join(ROOT_DIR, p)
            if os.path.isfile(abs_src):
                dst_name = os.path.basename(abs_src)
                dst = os.path.join(snapshot_path, dst_name)
                shutil.copy2(abs_src, dst)
                file_size = os.path.getsize(abs_src)
                copied_files.append({
                    'name': dst_name,
                    'size_bytes': file_size,
                    'size_mb': round(file_size / (1024 * 1024), 2)
                })
                print(f"   ✅ {dst_name}")
            else:
                print(f"   ⚠️  Bỏ qua (không tồn tại file): {p}")
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

def list_snapshots() -> None:
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
    # ==================== CLI ====================
    parser = argparse.ArgumentParser(
        description="Tạo và quản lý snapshots kết quả phân tích",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="Liệt kê tất cả snapshots hiện có"
    )
    parser.add_argument(
        "--name", type=str, default=None,
        help="Đặt tên snapshot tùy chọn (mặc định: snapshot_<timestamp>)"
    )
    parser.add_argument(
        "--extra", nargs='*', default=None,
        help="Các file bổ sung cần thêm vào snapshot (đường dẫn tuyệt đối hoặc tương đối)"
    )

    args = parser.parse_args()

    if args.list:
        list_snapshots()
    else:
        create_snapshot(snapshot_name=args.name, extra_paths=args.extra)
