#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# 📊 DỰ ÁN: Phân Tích Rửa Tiền — K-means (Polars + Spark)
# TIỆN ÍCH: DỌN SẠCH TOÀN BỘ ARTEFACTS (CLEAN ALL)
# ─────────────────────────────────────────────────────────────────────────────
# Mục tiêu: Xóa sạch artefacts local để chuẩn bị chạy lại pipeline từ đầu.
# Phạm vi xóa:
#   - data/processed/*, data/results/*
#   - logs/*.md
#   - snapshots/*
#   - visualizations artefacts (giữ notebook/README)
#   - .pipeline_checkpoints
# Cách chạy nhanh:
#   bash scripts/pipeline/clean_all.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DATA_PROCESSED="$ROOT_DIR/data/processed"
DATA_RESULTS="$ROOT_DIR/data/results"
LOGS_DIR="$ROOT_DIR/logs"
SNAPSHOTS_DIR="$ROOT_DIR/snapshots"
VIZ_DIR="$ROOT_DIR/visualizations"
CHECKPOINT_DIR="$ROOT_DIR/.pipeline_checkpoints"

echo "=== DỌN SẠCH TOÀN BỘ DỰ ÁN ==="
echo "Root: $ROOT_DIR"

# 1) Xóa dữ liệu đã xử lý và kết quả
echo "[1/6] Dọn data/processed và data/results..."
mkdir -p "$DATA_PROCESSED" "$DATA_RESULTS"
find "$DATA_PROCESSED" -mindepth 1 -maxdepth 1 -type f -print -delete || true
find "$DATA_RESULTS" -mindepth 1 -maxdepth 1 -type f -print -delete || true

# 2) Xóa logs
echo "[2/6] Dọn logs..."
mkdir -p "$LOGS_DIR"
find "$LOGS_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.md" -print -delete || true

# 3) Xóa snapshots
echo "[3/6] Dọn snapshots..."
if [ -d "$SNAPSHOTS_DIR" ]; then
  find "$SNAPSHOTS_DIR" -mindepth 1 -maxdepth 1 -print -exec rm -rf {} + || true
else
  mkdir -p "$SNAPSHOTS_DIR"
fi

# 4) Xóa artefacts visualization giữ lại notebook/README
echo "[4/6] Dọn visualizations artefacts..."
mkdir -p "$VIZ_DIR"
rm -f "$VIZ_DIR"/latest_summary.txt || true
rm -f "$VIZ_DIR"/visual_report_*.md || true
rm -f "$VIZ_DIR"/thong_ke_cum.csv || true

# 5) Reset checkpoints
echo "[5/6] Reset checkpoints..."
rm -rf "$CHECKPOINT_DIR" || true
mkdir -p "$CHECKPOINT_DIR"

# 6) (Tùy chọn) Dọn HDFS - bỏ comment nếu cần
# echo "[6/6] Dọn HDFS..."
# hdfs dfs -rm -r -f /user/spark/hi_large/input 2>/dev/null || true
# hdfs dfs -rm -r -f /user/spark/hi_large/output_centroids 2>/dev/null || true
# hdfs dfs -rm -f /user/spark/hi_large/centroids.txt 2>/dev/null || true

echo ""
echo "✅ Dọn sạch xong! Sẵn sàng chạy lại từ đầu."
echo "Gợi ý chạy: ./scripts/pipeline/full_pipeline_spark.sh --reset"


