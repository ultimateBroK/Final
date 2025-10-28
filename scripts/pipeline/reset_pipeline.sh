#!/bin/bash
# Script hỗ trợ reset các checkpoint của pipeline

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CHECKPOINT_DIR="$ROOT_DIR/.pipeline_checkpoints"

if [ "$1" == "all" ]; then
    rm -rf "$CHECKPOINT_DIR"
    echo "✅ Đã reset tất cả checkpoints"
elif [ "$1" == "status" ]; then
    echo "Trạng thái checkpoint của pipeline:"
    for i in {1..8}; do
        if [ -f "$CHECKPOINT_DIR/step_$i.done" ]; then
            timestamp=$(cat "$CHECKPOINT_DIR/step_$i.done")
            echo "  ✅ Bước $i - hoàn thành lúc $timestamp"
        else
            echo "  ⏳ Bước $i - chưa hoàn thành"
        fi
    done
elif [ "$1" == "from" ] && [ -n "$2" ]; then
    # Reset từ bước cụ thể trở đi
    for i in $(seq $2 8); do
        rm -f "$CHECKPOINT_DIR/step_$i.done"
    done
    echo "✅ Đã reset checkpoints từ bước $2 trở đi"
else
    echo "Cách sử dụng:"
    echo "  ./reset_pipeline.sh all        - Reset tất cả checkpoints"
    echo "  ./reset_pipeline.sh status     - Hiển thị trạng thái checkpoint"
    echo "  ./reset_pipeline.sh from N     - Reset từ bước N trở đi"
    echo ""
    echo "Ví dụ:"
    echo "  ./reset_pipeline.sh from 5     - Chạy lại từ bước 5 trở đi"
fi
