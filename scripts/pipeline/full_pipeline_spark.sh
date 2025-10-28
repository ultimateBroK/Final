#!/bin/bash

# Thư mục gốc dự án và các đường dẫn
ROOT_DIR="$(cd "$(dirname "$0")/../.."; pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
LOGS_DIR="$ROOT_DIR/logs"
DATA_DIR="$ROOT_DIR/data"

# Tạo file log với timestamp
mkdir -p "$LOGS_DIR"
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

# Hàm reset tất cả các checkpoint
reset_checkpoints() {
    rm -rf "$CHECKPOINT_DIR"
    mkdir -p "$CHECKPOINT_DIR"
    log "🔄 Đã reset tất cả checkpoints"
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

# Bắt đầu đếm thời gian tổng
TOTAL_START=$(date +%s)

# Khởi tạo file markdown
log "# Polars + PySpark Pipeline Execution Log"
log ""
log "**Thời gian bắt đầu:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**File log:** $LOG_FILE"
log ""
log "---"
log ""

log "## Thực thi Pipeline"
log ""
log "=== POLARS + PYSPARK PIPELINE ==="
log "Thời gian bắt đầu: $(date '+%Y-%m-%d %H:%M:%# Bước 1
log "### Bước 1: Khám phá dữ liệu"
log ""
if is_step_completed 1; then
    log "⏭️  Bước 1 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python explore_fast.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 1
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 1 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 1 thất bại"
        exit 1
    fi
fi
log ""

# Bước 2
log "### Bước 2: Chuẩn bị đặc trưng với Polars"
log ""
if is_step_completed 2; then
    log "⏭️  Bước 2 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python prepare_polars.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 2
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 2 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 2 thất bại"
        exit 1
    fi
fi
log ""

# Bước 3
log "### Bước 3: Khởi tạo tâm cụm"
log ""
if is_step_completed 3; then
    log "⏭️  Bước 3 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python init_centroids.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 3
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 3 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 3 thất bại"
        exit 1
    fi
fi
log ""

# Bước 4 - Upload lên HDFS
log "### Bước 4: Upload dữ liệu lên HDFS"
log ""
if is_step_completed 4; then
    log "⏭️  Bước 4 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/spark" && bash setup_hdfs.sh) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 4
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 4 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 4 thất bại"
        exit 1
    fi
fi
log ""

# Bước 5 - SPARK K-means trên HDFS
log "### Bước 5: Chạy PySpark K-means trên HDFS"
log ""
if is_step_completed 5; then
    log "⏭️  Bước 5 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/spark" && bash run_spark.sh) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 5
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 5 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 5 thất bại"
        exit 1
    fi
fi
log ""

# Bước 6 - Tải về từ HDFS
log "### Bước 6: Tải kết quả từ HDFS"
log ""
if is_step_completed 6; then
    log "⏭️  Bước 6 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/spark" && bash download_from_hdfs.sh) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 6
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 6 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 6 thất bại"
        exit 1
    fi
fi
log ""

# Bước 7
log "### Bước 7: Gán cụm với Polars"
log ""
if is_step_completed 7; then
    log "⏭️  Bước 7 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python assign_clusters_polars.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 7
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 7 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 7 thất bại"
        exit 1
    fi
fi
log ""

# Bước 8
log "### Bước 8: Phân tích kết quả"
log ""
if is_step_completed 8; then
    log "⏭️  Bước 8 đã hoàn thành, đang bỏ qua..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python analyze_polars.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 8
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Bước 8 hoàn thành trong $(format_time $STEP_TIME)**"
    else
        log "❌ Bước 8 thất bại"
        exit 1
    fi
fi
log ""

# Tổng thời gian
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))
log ""
log "---"
log ""
log "## Tổng kết"
log ""
log "✅ **Pipeline hoàn thành thành công!**"
log ""
log "**Thời gian kết thúc:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**Tổng thời gian chạy:** $(format_time $TOTAL_TIME)"
log ""
log "---"
log ""
log "*Log đã lưu tại: $LOG_FILE*"
