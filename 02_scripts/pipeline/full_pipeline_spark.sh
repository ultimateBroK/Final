#!/bin/bash
#
# POLARS + PYSPARK K-MEANS PIPELINE
#
# Mô tả: Pipeline tự động 7 bước sử dụng MLlib k-means++
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
TOTAL_STEPS=7

# Flags
RESET_MODE=false
DRY_RUN=false
FROM_STEP=1
SKIP_STEPS=()
VERBOSE=true
SEED=""
K_OVERRIDE=""
MAX_ITER_OVERRIDE=""
TOL_OVERRIDE=""

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
        --seed)
            SEED="$2"
            shift 2
            ;;
        --k)
            K_OVERRIDE="$2"
            shift 2
            ;;
        --max-iter)
            MAX_ITER_OVERRIDE="$2"
            shift 2
            ;;
        --tol)
            TOL_OVERRIDE="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
POLARS + PYSPARK K-MEANS PIPELINE

Sử dụng: $0 [OPTIONS]

OPTIONS:
  --reset           Reset checkpoints và chạy lại từ đầu
  --from-step N     Bắt đầu từ bước N (1-7)
  --skip-step N     Bỏ qua bước N
  --dry-run         Chỉ hiển thị kế hoạch
  --seed N          Thiết lập seed cho KMeans (ví dụ 42)
  --k N             Số cụm K cho KMeans (ví dụ 5)
  --max-iter N      Số vòng lặp tối đa KMeans (ví dụ 15)
  --tol FLOAT       Ngưỡng hội tụ (ví dụ 1e-4)
  --help, -h        Hiển thị hướng dẫn này

Ví dụ:
  $0                    # Chạy bình thường
  $0 --reset            # Reset và chạy lại
  $0 --from-step 5      # Chạy từ bước 5
  $0 --skip-step 1      # Bỏ qua bước 1
  $0 --dry-run          # Xem trước kế hoạch

Cấu trúc pipeline (7 bước):
  1. Khám phá dữ liệu
  2. Xử lý đặc trưng
  3. Upload lên HDFS
  4. Chạy K-means MLlib
  5. Tải kết quả về
  6. Gán nhãn cụm
  7. Phân tích kết quả

EOF
            exit 0
            ;;
        *)
            echo "Lỗi: Tham số không hợp lệ: $1"
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

# Hàm ghi log CHỈ vào file (không in ra terminal để tránh trùng lặp)
log() {
    echo "$1" >> "$LOG_FILE"
}

# In ra terminal có màu (không ghi vào log)
term() {
    # Điều khiển màu: chỉ in ra terminal để tránh escape vào log
    # Sử dụng >&2 để tách khỏi tee của log()
    echo -e "$1" >&2
}

# Màu cơ bản cho terminal
COLOR_RESET='\033[0m'
COLOR_BOLD='\033[1m'
COLOR_BLUE='\033[34m'
COLOR_GREEN='\033[32m'
COLOR_YELLOW='\033[33m'
COLOR_RED='\033[31m'

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
    log "Đã đặt lại tất cả các điểm đánh dấu"
}

# Hàm kiểm tra điều kiện trước khi chạy
check_prerequisites() {
    local errors=0
    
    log "KIỂM TRA ĐIỀU KIỆN..."
    
    # Kiểm tra Python
    if ! command -v python &> /dev/null; then
        log "   Python không tìm thấy"
        ((errors++))
    else
        log "   Python: $(python --version)"
    fi
    
    # Kiểm tra HDFS
    if ! command -v hdfs &> /dev/null; then
        log "   Lệnh HDFS không tìm thấy (cần cho bước 4-6)"
    elif hdfs dfs -test -e / 2>/dev/null; then
        log "   HDFS đang chạy"
    else
        log "   HDFS chưa khởi động (cần cho bước 4-6)"
    fi
    
    # Kiểm tra file CSV
    if [[ ! -f "$DATA_DIR/raw/HI-Large_Trans.csv" ]]; then
        log "   Không tìm thấy tệp CSV: $DATA_DIR/raw/HI-Large_Trans.csv"
        ((errors++))
    else
        local size=$(du -h "$DATA_DIR/raw/HI-Large_Trans.csv" | cut -f1)
        log "   Tệp CSV: $size"
    fi
    
    # Kiểm tra RAM khả dụng
    local available_ram=$(free -g | awk '/^Mem:/{print $7}')
    if [[ $available_ram -lt 8 ]]; then
        log "   RAM khả dụng: ${available_ram}GB (khuyến nghị ≥ 8GB)"
    else
        log "   RAM khả dụng: ${available_ram}GB"
    fi
    
    # Kiểm tra disk space
    local available_disk=$(df -h "$ROOT_DIR" | awk 'NR==2 {print $4}')
    log "   Dung lượng đĩa khả dụng: $available_disk"
    
    log ""
    
    if [[ $errors -gt 0 ]]; then
        log "Có $errors lỗi cần sửa trước khi chạy"
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
    
    local percent=$((completed * 100 / TOTAL_STEPS))
    local bar_length=20
    local filled=$((completed * bar_length / TOTAL_STEPS))
    local empty=$((bar_length - filled))
    
    printf "${COLOR_BOLD}${COLOR_BLUE}   Tiến độ:${COLOR_RESET} [" >&2
    printf "%${filled}s" | tr ' ' '█' >&2
    printf "%${empty}s" | tr ' ' '░' >&2
    printf "] %d/%d (%d%%)\n" $completed $TOTAL_STEPS $percent >&2
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
    
    term "${COLOR_BOLD}${COLOR_BLUE}\n================================================================${COLOR_RESET}"
    term "${COLOR_BOLD}${COLOR_BLUE}Bước $step_num/${TOTAL_STEPS}:${COLOR_RESET} ${COLOR_BOLD}$step_name${COLOR_RESET}"
    term "${COLOR_BOLD}${COLOR_BLUE}├─${COLOR_RESET} Mục đích: $step_desc"
    term "${COLOR_BOLD}${COLOR_BLUE}└─${COLOR_RESET} Thời gian ước tính: $step_time"
    log "### Bước $step_num/${TOTAL_STEPS}: $step_name"
    log ""
    log "**Mục đích:** $step_desc"
    log "**Thời gian ước tính:** $step_time"
    log ""
    
    if [[ $FROM_STEP -gt $step_num ]] || is_step_skipped $step_num; then
        term "${COLOR_YELLOW}Bỏ qua bước $step_num${COLOR_RESET}"
        log "Bỏ qua bước $step_num"
    elif is_step_completed $step_num; then
        term "${COLOR_GREEN}Bước $step_num đã hoàn thành trước đó${COLOR_RESET}"
        log "Bước $step_num đã hoàn thành trước đó"
    elif [[ "$DRY_RUN" == "true" ]]; then
        term "${COLOR_YELLOW}[Chạy thử] Sẽ chạy: $command${COLOR_RESET}"
        log "[Chạy thử] Sẽ chạy: $command"
    else
        STEP_START=$(date +%s)
        term ""
        term "${COLOR_YELLOW}Đang chạy bước $step_num...${COLOR_RESET}"
        term "${COLOR_YELLOW}----------------------------------------------------------------${COLOR_RESET}"
        log "Đang chạy..."
        
        # Chạy command và hiển thị output real-time (không buffer)
        # stdbuf -o0 -e0: disable buffering để thấy output ngay lập tức
        if stdbuf -o0 -e0 bash -c "$command" 2>&1 | tee -a "$LOG_FILE"; then
            mark_step_completed $step_num
            STEP_END=$(date +%s)
            STEP_TIME_ACTUAL=$((STEP_END - STEP_START))
            term ""
            term "${COLOR_YELLOW}----------------------------------------------------------------${COLOR_RESET}"
            log ""
            term "${COLOR_GREEN}Hoàn thành: ${COLOR_BOLD}Bước $step_num${COLOR_RESET}${COLOR_GREEN} trong $(format_time $STEP_TIME_ACTUAL)${COLOR_RESET}"
            log "**Bước $step_num hoàn thành trong $(format_time $STEP_TIME_ACTUAL)**"
        else
            term ""
            term "${COLOR_RED}Thất bại: ${COLOR_BOLD}Bước $step_num${COLOR_RESET}${COLOR_RED}. Kiểm tra log ở trên.${COLOR_RESET}"
            log ""
            log "**Bước $step_num thất bại! Kiểm tra log ở trên.**"
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

# Khởi tạo file markdown + banner terminal
term "${COLOR_BOLD}${COLOR_BLUE}===============================================================${COLOR_RESET}"
term "${COLOR_BOLD}${COLOR_BLUE}Polars + PySpark Pipeline${COLOR_RESET}"
term "${COLOR_BOLD}${COLOR_BLUE}===============================================================${COLOR_RESET}"
log "# Polars + PySpark Pipeline"
log ""
log "**Thời gian bắt đầu:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**File log:** \`$LOG_FILE\`"
log "**Chế độ:** $([ "$DRY_RUN" == "true" ] && echo "Chạy thử" || echo "Thực thi")"
if [[ $FROM_STEP -gt 1 ]]; then
    log "**Bắt đầu từ:** Bước $FROM_STEP"
fi
if [[ ${#SKIP_STEPS[@]} -gt 0 ]]; then
    log "**Bỏ qua:** Bước ${SKIP_STEPS[*]}"
fi
if [[ -n "$SEED" ]]; then
    log "**Hạt giống (seed):** $SEED"
    term "${COLOR_BOLD}${COLOR_BLUE}Hạt giống (seed):${COLOR_RESET} $SEED"
fi
if [[ -n "$K_OVERRIDE" ]]; then
    log "**Số cụm K (ghi đè):** $K_OVERRIDE"
    term "${COLOR_BOLD}${COLOR_BLUE}Số cụm K:${COLOR_RESET} $K_OVERRIDE"
fi
if [[ -n "$MAX_ITER_OVERRIDE" ]]; then
    log "**Số vòng lặp tối đa (ghi đè):** $MAX_ITER_OVERRIDE"
    term "${COLOR_BOLD}${COLOR_BLUE}Số vòng lặp tối đa:${COLOR_RESET} $MAX_ITER_OVERRIDE"
fi
if [[ -n "$TOL_OVERRIDE" ]]; then
    log "**Ngưỡng hội tụ (ghi đè):** $TOL_OVERRIDE"
    term "${COLOR_BOLD}${COLOR_BLUE}Ngưỡng hội tụ:${COLOR_RESET} $TOL_OVERRIDE"
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
    "Trích xuất đặc trưng: thời gian → giờ/ngày, tỷ lệ số tiền, mã tuyến, chuẩn hóa" \
    "~10 phút (6 bước nhỏ)" \
    "python \"$SCRIPTS_DIR/polars/02_prepare_polars.py\""

run_step 3 "Upload Lên HDFS" \
    "Tải dữ liệu lên HDFS, xóa tệp tạm trên máy" \
    "~5 phút" \
    "bash \"$SCRIPTS_DIR/spark/setup_hdfs.sh\""

run_step 4 "K-means MLlib (Tối ưu)" \
    "K-means MLlib: khởi tạo k-means++, tối ưu hóa Catalyst, Tungsten, hiển thị chi tiết từng vòng lặp" \
    "~10-15 phút (nhanh hơn 30-50%, 5 bước)" \
    "bash \"$SCRIPTS_DIR/spark/run_spark.sh\" ${K_OVERRIDE:+--k $K_OVERRIDE} ${MAX_ITER_OVERRIDE:+--max-iter $MAX_ITER_OVERRIDE} ${SEED:+--seed $SEED} ${TOL_OVERRIDE:+--tol $TOL_OVERRIDE}"

run_step 5 "Tải Kết Quả Về" \
    "Tải tâm cụm cuối cùng từ HDFS về máy" \
    "~30 giây" \
    "bash \"$SCRIPTS_DIR/spark/download_from_hdfs.sh\""

run_step 6 "Gán Nhãn Cụm" \
    "Gán nhãn cụm cho từng giao dịch" \
    "~10 phút" \
    "python \"$SCRIPTS_DIR/polars/04_assign_clusters.py\""

run_step 7 "Phân Tích Kết Quả" \
    "Phân tích thống kê và tìm cụm rủi ro cao" \
    "~2 phút" \
    "python \"$SCRIPTS_DIR/polars/05_analyze.py\""

# ==================== TỔNG KẾT ====================
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))
log ""
log "═══════════════════════════════════════════════════════════════"
log ""
log "## Tổng Kết Pipeline"
log ""
log "**Pipeline hoàn thành thành công!**"
log ""
log "**Thời gian kết thúc:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**Tổng thời gian chạy:** $(format_time $TOTAL_TIME)"
log ""
log "---"
log ""
log "### Thống Kê Kết Quả"
log ""

# Thống kê kết quả
if [[ -f "$DATA_DIR/results/clustered_results.txt" ]]; then
    total_transactions=$(wc -l < "$DATA_DIR/results/clustered_results.txt")
    log "- Tổng giao dịch đã phân cụm: **$(printf "%'d" $total_transactions)**"
fi

if [[ -f "$DATA_DIR/results/final_centroids.txt" ]]; then
    num_clusters=$(wc -l < "$DATA_DIR/results/final_centroids.txt")
    log "- Số cụm: **$num_clusters**"
fi

log_size=$(du -h "$LOG_FILE" | cut -f1)
log "- Kích thước log: **$log_size**"

log ""
log "---"
log ""
log "### Bước Tiếp Theo"
log ""
log "1) Tạo snapshot: python 02_scripts/data/snapshot_results.py"
log "2) Trực quan hóa: python 02_scripts/data/visualize_results.py"
log "3) Xem notebook: jupyter lab 06_visualizations/phan-tich.ipynb"
log ""
log "---"
log ""
log "### Các tệp quan trọng"
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
log "═══════════════════════════════════════════════════════════════"

if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    echo "Pipeline hoàn thành."
    echo ""
    echo "Log chi tiết: $LOG_FILE"
    echo "Xem kết quả: cat 01_data/results/clustered_results.txt | head"
    echo "Bước tiếp theo: python 02_scripts/data/snapshot_results.py"
    echo "Trực quan hóa: cd 06_visualizations && jupyter lab phan-tich.ipynb"
    echo "Chạy với tham số: $0 --help"
    echo ""
fi