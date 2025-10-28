#!/bin/bash

# Project root and paths
ROOT_DIR="$(cd "$(dirname "$0")/../.."; pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
LOGS_DIR="$ROOT_DIR/logs"
DATA_DIR="$ROOT_DIR/data"

# Tạo file log với timestamp
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/pipeline_log_$(date +%Y%m%d_%H%M%S).md"
CHECKPOINT_DIR="$ROOT_DIR/.pipeline_checkpoints"
mkdir -p "$CHECKPOINT_DIR"

# Function to log to both terminal and file
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to check if step is completed
is_step_completed() {
    [ -f "$CHECKPOINT_DIR/step_$1.done" ]
}

# Function to mark step as completed
mark_step_completed() {
    touch "$CHECKPOINT_DIR/step_$1.done"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$CHECKPOINT_DIR/step_$1.done"
}

# Function to reset all checkpoints
reset_checkpoints() {
    rm -rf "$CHECKPOINT_DIR"
    mkdir -p "$CHECKPOINT_DIR"
    log "🔄 All checkpoints reset"
}

# Function to format time
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

# Start total timer
TOTAL_START=$(date +%s)

# Khởi tạo file markdown
log "# Polars + PySpark Pipeline Execution Log"
log ""
log "**Start Time:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**Log File:** $LOG_FILE"
log ""
log "---"
log ""

log "## Pipeline Execution"
log ""
log "=== POLARS + PYSPARK PIPELINE ==="
log "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

# Step 1
log "### Step 1: Explore data"
log ""
if is_step_completed 1; then
    log "⏭️  Step 1 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python explore_fast.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 1
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 1 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 1 failed"
        exit 1
    fi
fi
log ""

# Step 2
log "### Step 2: Prepare features with Polars"
log ""
if is_step_completed 2; then
    log "⏭️  Step 2 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python prepare_polars.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 2
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 2 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 2 failed"
        exit 1
    fi
fi
log ""

# Step 3
log "### Step 3: Initialize centroids"
log ""
if is_step_completed 3; then
    log "⏭️  Step 3 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python init_centroids.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 3
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 3 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 3 failed"
        exit 1
    fi
fi
log ""

# Step 4 - Upload to HDFS
log "### Step 4: Upload data to HDFS"
log ""
if is_step_completed 4; then
    log "⏭️  Step 4 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/spark" && bash setup_hdfs.sh) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 4
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 4 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 4 failed"
        exit 1
    fi
fi
log ""

# Step 5 - SPARK K-means on HDFS
log "### Step 5: Run PySpark K-means on HDFS"
log ""
if is_step_completed 5; then
    log "⏭️  Step 5 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/spark" && bash run_spark.sh) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 5
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 5 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 5 failed"
        exit 1
    fi
fi
log ""

# Step 6 - Download from HDFS
log "### Step 6: Download results from HDFS"
log ""
if is_step_completed 6; then
    log "⏭️  Step 6 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/spark" && bash download_from_hdfs.sh) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 6
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 6 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 6 failed"
        exit 1
    fi
fi
log ""

# Step 7
log "### Step 7: Assign clusters with Polars"
log ""
if is_step_completed 7; then
    log "⏭️  Step 7 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python assign_clusters_polars.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 7
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 7 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 7 failed"
        exit 1
    fi
fi
log ""

# Step 8
log "### Step 8: Analyze results"
log ""
if is_step_completed 8; then
    log "⏭️  Step 8 already completed, skipping..."
else
    STEP_START=$(date +%s)
    (cd "$SCRIPTS_DIR/polars" && python analyze_polars.py) 2>&1 | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        mark_step_completed 8
        STEP_END=$(date +%s)
        STEP_TIME=$((STEP_END - STEP_START))
        log "⏱️  **Step 8 completed in $(format_time $STEP_TIME)**"
    else
        log "❌ Step 8 failed"
        exit 1
    fi
fi
log ""

# Total time
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))
log ""
log "---"
log ""
log "## Summary"
log ""
log "✅ **Pipeline completed successfully!**"
log ""
log "**End Time:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**Total Runtime:** $(format_time $TOTAL_TIME)"
log ""
log "---"
log ""
log "*Log saved to: $LOG_FILE*"
