#!/bin/bash

# Tạo file log với timestamp
LOG_FILE="pipeline_log_$(date +%Y%m%d_%H%M%S).md"
CHECKPOINT_DIR=".pipeline_checkpoints"
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
log "# Polars + Hadoop Pipeline Execution Log"
log ""
log "**Start Time:** $(date '+%Y-%m-%d %H:%M:%S')"
log "**Log File:** $LOG_FILE"
log ""
log "---"
log ""

log "## Pipeline Execution"
log ""
log "=== POLARS + HADOOP PIPELINE ==="
log "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

# Step 1
log "### Step 1: Explore data"
log ""
if is_step_completed 1; then
    log "⏭️  Step 1 already completed, skipping..."
else
    STEP_START=$(date +%s)
    python explore_fast.py 2>&1 | tee -a "$LOG_FILE"
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
    python prepare_polars.py 2>&1 | tee -a "$LOG_FILE"
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
    python init_centroids.py 2>&1 | tee -a "$LOG_FILE"
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

# Step 4
log "### Step 4: Run Hadoop MapReduce"
log ""
if is_step_completed 4; then
    log "⏭️  Step 4 already completed, skipping..."
else
    STEP_START=$(date +%s)
    bash run_hadoop_optimized.sh 2>&1 | tee -a "$LOG_FILE"
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

# Step 5
log "### Step 5: Assign clusters with Polars"
log ""
if is_step_completed 5; then
    log "⏭️  Step 5 already completed, skipping..."
else
    STEP_START=$(date +%s)
    python assign_clusters_polars.py 2>&1 | tee -a "$LOG_FILE"
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

# Step 6
log "### Step 6: Analyze results"
log ""
if is_step_completed 6; then
    log "⏭️  Step 6 already completed, skipping..."
else
    STEP_START=$(date +%s)
    python analyze_polars.py 2>&1 | tee -a "$LOG_FILE"
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
