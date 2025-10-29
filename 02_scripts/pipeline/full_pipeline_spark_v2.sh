#!/bin/bash
#
# 🚀 POLARS + PYSPARK K-MEANS PIPELINE - SIÊU VIỆT EDITION
#
# Mô tả: Pipeline tự động 7 bước xử lý 179 triệu giao dịch (MLlib k-means++)
# Tác giả: Dự Án Phân Tích Rửa Tiền
# Version: 2.0 (Siêu Việt Edition)
# Ngày: 2025-10-29
#
# Sử dụng:
#   ./02_scripts/pipeline/full_pipeline_spark_v2.sh [OPTIONS]
#
# OPTIONS:
#   --reset        Reset tất cả checkpoints và chạy lại từ đầu
#   --from-step N  Bắt đầu từ bước N
#   --skip-step N  Bỏ qua bước N
#   --dry-run      Chỉ hiển thị kế hoạch, không chạy
#   --help         Hiển thị hướng dẫn
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ==================== CẤU HÌNH ====================
ROOT_DIR="$(cd "$(dirname "$0")/../.."; pwd)"
SCRIPTS_DIR="$ROOT_DIR/02_scripts"
LOGS_DIR="$ROOT_DIR/04_logs"
DATA_DIR="$ROOT_DIR/01_data"
SNAPSHOTS_DIR="$ROOT_DIR/05_snapshots"
VIZ_DIR="$ROOT_DIR/06_visualizations"

# Flags
RESET_MODE=false
DRY_RUN=false
FROM_STEP=1
SKIP_STEPS=()
VERBOSE=true

# ==================== PARSE ARGUMENTS ====================
while [[ $# -gt 0 ]]; do
    case $1 in
        --reset)
            RESET_MODE=true
            shift
            ;;
        --from-step)
            FROM_STEP="$2"
            shift 2
            ;;
        --skip-step)
            SKIP_STEPS+=("$2")
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            cat << EOF
🚀 POLARS + PYSPARK K-MEANS PIPELINE - SIÊU VIỆT EDITION

Sử dụng: $0 [OPTIONS]

OPTIONS:
  --reset           Reset checkpoints và chạy lại từ đầu
  --from-step N     Bắt đầu từ bước N (1-7)
  --skip-step N     Bỏ qua bước N
  --dry-run         Chỉ hiển thị kế hoạch
  --help, -h        Hiển thị hướng dẫn này

VÍ DỤ:
  $0                    # Chạy bình thường
  $0 --reset            # Reset và chạy lại
  $0 --from-step 5      # Chạy từ bước 5
  $0 --skip-step 1      # Bỏ qua bước 1
  $0 --dry-run          # Xem trước kế hoạch

CẤU TRÚC PIPELINE (7 BƯỚC):
  1. Khám phá dữ liệu           (~30s)
  2. Xử lý đặc trưng         (~10 phút)
  3. Upload lên HDFS          (~5 phút)
  4. Chạy K-means MLlib      (~10-15 phút) ⭐ NÓNG!
  5. Tải kết quả về           (~30s)
  6. Gán nhãn cụm             (~10 phút)
  7. Phân tích kết quả         (~2 phút)

TỔNG THỜI GIAN ƯỚC TÍNH: 30-40 phút (⚡ Nhanh hơn 30-50%!)

EOF
            exit 0
            ;;
        *)
            echo "❌ Lỗi: Tham số không hợp lệ: $1"
            echo "Sử dụng --help để xem hướng dẫn"
            exit 1
            ;;
    esac
done

# ==================== KHỞI TẠO ====================
mkdir -p "$LOGS_DIR" "$SNAPSHOTS_DIR"
LOG_FILE="$LOGS_DIR/pipeline_log_$(date +%Y%m%d_%H%M%S).md"
CHECKPOINT_DIR="$ROOT_DIR/.pipeline_checkpoints"
mkdir -p "$CHECKPOINT_DIR"

# Hàm ghi log ra cả terminal và file
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Hàm kiểm tra xem bước đã hoàn thành chưa
is_step_completed() {
    [ -f "$CHECKPOINT_DIR/step_$1.done" ]
}

# Hàm đánh dấu bước đã hoàn thành
mark_step_completed() {
    touch "$CHECKPOINT_DIR/step_$1.done"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$CHECKPOINT_DIR/step_$1.done"
}

# Hàm kiểm tra xem có bỏ qua bước này không
is_step_skipped() {
    for skip in "${SKIP_STEPS[@]-}"; do
        if [[ "$skip" == "$1" ]]; then
            return 0
        fi
    done
    return 1
}

# Hàm reset tất cả các checkpoint
reset_checkpoints() {
    rm -rf "$CHECKPOINT_DIR"
    mkdir -p "$CHECKPOINT_DIR"
    log "🔄 Đã reset tất cả checkpoints"
}

# Hàm kiểm tra điều kiện trước khi chạy
check_prerequisites() {
    local errors=0
    
    log "🔍 KIỂM TRA ĐIỀU KIỆN..."
    
    # Kiểm tra Python
    if ! command -v python &> /dev/null; then
        log "   ❌ Python không tìm thấy"
        ((errors++))
    else
        log "   ✅ Python: $(python --version)"
    fi
    
    # Kiểm tra HDFS
    if ! command -v hdfs &> /dev/null; then
        log "   ⚠️  HDFS command không tìm thấy (sẽ cần cho bước 4-6)"
    elif hdfs dfs -test -e / 2>/dev/null; then
        log "   ✅ HDFS đang chạy"
    else
        log "   ⚠️  HDFS chưa khởi động (sẽ cần cho bước 4-6)"
    fi
    
    # Kiểm tra file CSV
    if [[ ! -f "$DATA_DIR/raw/HI-Large_Trans.csv" ]]; then
        log "   ❌ File CSV không tìm thấy: $DATA_DIR/raw/HI-Large_Trans.csv"
        ((errors++))
    else
        local size=$(du -h "$DATA_DIR/raw/HI-Large_Trans.csv" | cut -f1)
        log "   ✅ File CSV: $size"
    fi
    
    # Kiểm tra RAM khả dụng
    local available_ram=$(free -g | awk '/^Mem:/{print $7}')
    if [[ $available_ram -lt 8 ]]; then
        log "   ⚠️  RAM khả dụng: ${available_ram}GB (khuyến nghị ≥ 8GB)"
    else
        log "   ✅ RAM khả dụng: ${available_ram}GB"
    fi
    
    # Kiểm tra disk space
    local available_disk=$(df -h "$ROOT_DIR" | awk 'NR==2 {print $4}')
    log "   💾 Disk khả dụng: $available_disk"
    
    log ""
    
    if [[ $errors -gt 0 ]]; then
        log "❌ Có $errors lỗi phải sửa trước khi chạy!"
        exit 1
    fi
}

# Hàm thống kê tiến độ
show_progress() {
    local completed=0
    for i in 1 2 3 4 5 6 7; do
        if is_step_completed $i; then
            ((completed++)) || true
        fi
    done
    
    local percent=$((completed * 100 / 7))
    local bar_length=20
    local filled=$((completed * bar_length / 7))
    local empty=$((bar_length - filled))
    
    printf "   Tiến độ: [" >&2
    printf "%${filled}s" | tr ' ' '█' >&2
    printf "%${empty}s" | tr ' ' '░' >&2
    printf "] %d/8 (%d%%)\n" $completed $percent >&2
}

# Hàm định dạng thời gian
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Hàm chạy một bước pipeline
run_step() {
    local step_num=$1
    local step_name="$2"
    local step_desc="$3"
    local step_time="$4"
    local command="$5"
    
    log "### 🔢 Bước $step_num/8: $step_name"
    log ""
    log "**Mục đích:** $step_desc"
    log "**Thời gian ước tính:** $step_time"
    log ""
    
    if [[ $FROM_STEP -gt $step_num ]] || is_step_skipped $step_num; then
        log "⏩ Bỏ qua bước $step_num"
    elif is_step_completed $step_num; then
        log "✅ Bước $step_num đã hoàn thành trước đó"
    elif [[ "$DRY_RUN" == "true" ]]; then
        log "📖 [Dry Run] Sẽ chạy: $command"
    else
        STEP_START=$(date +%s)
        log "🛠️  Đang chạy..."
        
        if eval "$command" 2>&1 | tee -a "$LOG_FILE"; then
            mark_step_completed $step_num
            STEP_END=$(date +%s)
            STEP_TIME_ACTUAL=$((STEP_END - STEP_START))
            log ""
            log "✅ **Bước $step_num hoàn thành trong $(format_time $STEP_TIME_ACTUAL)**"
        else
            log ""
            log "❌ **Bước $step_num thất bại! Kiểm tra log ở trên.**"
            exit 1
        fi
    fi
    log ""
    log "---"
    log ""
}

# ==================== RESET NẾU CẦN ====================
if [[ "$RESET_MODE" == "true" ]]; then
    reset_checkpoints
    log "🔄 Chế độ reset: Xóa tất cả checkpoints"
fi

# ==================== KIỂM TRA ĐIỀU KIỆN ====================
if [[ "$DRY_RUN" == "false" ]]; then
    check_prerequisites
fi

# ==================== BẮT ĐẦU PIPELINE ====================
TOTAL_START=$(date +%s)

# Khởi tạo file markdown
log "# 🚀 Polars + PySpark Pipeline - Siêu Việt Edition"
log ""
log "**Thời gian bắt đầu:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**File log:** \`$LOG_FILE\`"
log "**Chế độ:** $([ "$DRY_RUN" == "true" ] && echo "Dry Run" || echo "Thực thi")"
if [[ $FROM_STEP -gt 1 ]]; then
    log "**Bắt đầu từ:** Bước $FROM_STEP"
fi
if [[ ${#SKIP_STEPS[@]} -gt 0 ]]; then
    log "**Bỏ qua:** Bước ${SKIP_STEPS[*]}"
fi
log ""
log "---"
log ""

# Hiển thị tiến độ hiện tại
log "## Tiến độ Hiện Tại"
log ""
if [[ "$DRY_RUN" == "false" ]]; then
    show_progress
fi
log ""
log "---"
log ""

log "## Thực Thi Pipeline"
log ""

# ==================== CÁC BƯỚC PIPELINE ====================

run_step 1 "Khám Phá Dữ Liệu" \
    "Phân tích thống kê sơ bộ CSV, hiểu cấu trúc dữ liệu" \
    "~30 giây" \
    "python \"$SCRIPTS_DIR/polars/01_explore_fast.py\""

run_step 2 "Xử Lý Đặc Trưng" \
    "Feature engineering, normalization, tạo file temp" \
    "~10 phút" \
    "python \"$SCRIPTS_DIR/polars/02_prepare_polars.py\""

run_step 3 "Upload Lên HDFS" \
    "Upload dữ liệu lên HDFS, xóa temp files local" \
    "~5 phút" \
    "bash \"$SCRIPTS_DIR/spark/setup_hdfs.sh\""

run_step 4 "K-means MLlib (Tối Ưu)" \
    "K-means với MLlib: k-means++, Catalyst optimizer, Tungsten" \
    "~10-15 phút (⚡ Nhanh hơn 30-50%)" \
    "bash \"$SCRIPTS_DIR/spark/run_spark.sh\""

run_step 5 "Tải Kết Quả Về" \
    "Download final centroids từ HDFS về local" \
    "~30 giây" \
    "bash \"$SCRIPTS_DIR/spark/download_from_hdfs.sh\""

run_step 6 "Gán Nhãn Cụm" \
    "Assign cluster labels cho từng giao dịch" \
    "~10 phút" \
    "python \"$SCRIPTS_DIR/polars/04_assign_clusters.py\""

run_step 7 "Phân Tích Kết Quả" \
    "Statistical analysis và tìm high-risk clusters" \
    "~2 phút" \
    "python \"$SCRIPTS_DIR/polars/05_analyze.py\""

# ==================== TỔNG KẾT ====================
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))
log ""
log "═══════════════════════════════════════════════════════════════"
log ""
log "## 🎉 Tổng Kết Pipeline"
log ""
log "✅ **Pipeline hoàn thành thành công!**"
log ""
log "**Thời gian kết thúc:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**Tổng thời gian chạy:** $(format_time $TOTAL_TIME)"
log ""
log "---"
log ""
log "### 📊 Thống Kê Kết Quả"
log ""

# Thống kê kết quả
if [[ -f "$DATA_DIR/results/clustered_results.txt" ]]; then
    total_transactions=$(wc -l < "$DATA_DIR/results/clustered_results.txt")
    log "- 📊 Tổng giao dịch đã phân cụm: **$(printf "%'d" $total_transactions)**"
fi

if [[ -f "$DATA_DIR/results/final_centroids.txt" ]]; then
    num_clusters=$(wc -l < "$DATA_DIR/results/final_centroids.txt")
    log "- 🎯 Số cụm: **$num_clusters**"
fi

log_size=$(du -h "$LOG_FILE" | cut -f1)
log "- 📝 Kích thước log: **$log_size**"

log ""
log "---"
log ""
log "### 🚀 Bước Tiếp Theo"
log ""
log "#### 1️⃣ **Tạo Snapshot Kết Quả**"
log "   Lưu lại kết quả này để so sánh sau này:"
log "   \`\`\`bash"
log "   python 02_scripts/data/snapshot_results.py"
log "   \`\`\`"
log ""
log "#### 2️⃣ **Trực Quan Hóa Kết Quả**"
log "   Tạo biểu đồ ASCII hoặc chạy Jupyter notebook:"
log "   \`\`\`bash"
log "   # Biểu đồ ASCII"
log "   python 02_scripts/data/visualize_results.py"
log "   "
log "   # Hoặc Jupyter notebook"
log "   cd 06_visualizations"
log "   jupyter lab phan-tich.ipynb"
log "   \`\`\`"
log ""
log "#### 3️⃣ **Kiểm Tra Kết Quả HDFS**"
log "   Xem dữ liệu trên HDFS:"
log "   \`\`\`bash"
log "   hdfs dfs -ls -h /user/spark/hi_large/"
log "   hdfs dfs -du -h /user/spark/hi_large/"
log "   \`\`\`"
log ""
log "#### 4️⃣ **Đọc Báo Cáo Chi Tiết**"
log "   \`\`\`bash"
log "   cat BAO_CAO_DU_AN.md"
log "   \`\`\`"
log ""
log "#### 5️⃣ **Chạy Lại Với Tham Số Khác**"
log "   \`\`\`bash"
log "   # Reset và chạy lại từ đầu"
log "   ./02_scripts/pipeline/full_pipeline_spark_v2.sh --reset"
log "   "
log "   # Chạy lại từ bước 5 (Spark)"
log "   ./02_scripts/pipeline/full_pipeline_spark_v2.sh --from-step 5"
log "   "
log "   # Dry run để xem kế hoạch"
log "   ./02_scripts/pipeline/full_pipeline_spark_v2.sh --dry-run"
log "   \`\`\`"
log ""
log "#### 6️⃣ **Tối Ưu Và Thử Nghiệm**"
log "   \`\`\`bash"
log "   # Thử K khác nhau (sửa trong scripts)"
log "   # Thử feature engineering khác"
log "   # Thử parameter tuning cho Spark"
log "   # So sánh với supervised learning"
log "   \`\`\`"
log ""
log "---"
log ""
log "### 💾 Files Quan Trọng"
log ""
log "| File | Vị Trí | Mô Tả |"
log "|------|----------|--------|"
log "| Log này | \`$LOG_FILE\` | Chi tiết thực thi |"
log "| Kết quả | \`01_data/results/clustered_results.txt\` | Nhãn cụm |"
log "| Tâm cụm | \`01_data/results/final_centroids.txt\` | 5 tâm cụm (MLlib) |"
log "| Báo cáo | \`BAO_CAO_DU_AN.md\` | Báo cáo đầy đủ |"
log "| Notebook | \`06_visualizations/phan-tich.ipynb\` | Phân tích visual |"
log ""
log "---"
log ""
log "### 🎯 Gợi Ý Nghiên Cứu Tiếp"
log ""
log "1. **Model Comparison**: So sánh K-means vs. DBSCAN, vs. Isolation Forest"
log "2. **Supervised Learning**: Dùng labels để train Random Forest/XGBoost"
log "3. **Feature Engineering**: Thêm graph features, temporal patterns"
log "4. **Real-time**: Implement streaming với Spark Streaming + Kafka"
log "5. **Deployment**: Containerize với Docker + Kubernetes"
log "6. **Monitoring**: Thêm metrics với Prometheus + Grafana"
log ""
log "👍 **Chúc mừng! Pipeline đã chạy thành công.**"
log ""
log "═══════════════════════════════════════════════════════════════"

if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    echo "🎉 PIPELINE HOÀN THÀNH SIÊU VIỆT!"
    echo ""
    echo "📝 Log chi tiết: $LOG_FILE"
    echo "📊 Xem kết quả: cat 01_data/results/clustered_results.txt | head"
    echo "🚀 Bước tiếp theo: python 02_scripts/data/snapshot_results.py"
    echo "📈 Visualization: cd 06_visualizations && jupyter lab phan-tich.ipynb"
    echo "🎯 Chạy với options: $0 --help"
    echo ""
    echo "🌟 Các tính năng mới trong v2.0:"
    echo "   ✅ Command line arguments (--reset, --from-step, --skip-step, --dry-run)"
    echo "   ✅ Comprehensive prerequisite checking"
    echo "   ✅ Visual progress bar"
    echo "   ✅ Detailed step descriptions"
    echo "   ✅ Rich suggestions for next steps"
    echo "   ✅ Better error handling và logging"
    echo "   ✅ Research suggestions"
    echo ""
fi