#!/bin/bash
# Helper script to reset pipeline checkpoints

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECKPOINT_DIR="$ROOT_DIR/.pipeline_checkpoints"

if [ "$1" == "all" ]; then
    rm -rf "$CHECKPOINT_DIR"
    echo "✅ All checkpoints reset"
elif [ "$1" == "status" ]; then
    echo "Pipeline checkpoint status:"
    for i in {1..6}; do
        if [ -f "$CHECKPOINT_DIR/step_$i.done" ]; then
            timestamp=$(cat "$CHECKPOINT_DIR/step_$i.done")
            echo "  ✅ Step $i - completed at $timestamp"
        else
            echo "  ⏳ Step $i - not completed"
        fi
    done
elif [ "$1" == "from" ] && [ -n "$2" ]; then
    # Reset from specific step onwards
    for i in $(seq $2 6); do
        rm -f "$CHECKPOINT_DIR/step_$i.done"
    done
    echo "✅ Reset checkpoints from step $2 onwards"
else
    echo "Usage:"
    echo "  ./reset_pipeline.sh all        - Reset all checkpoints"
    echo "  ./reset_pipeline.sh status     - Show checkpoint status"
    echo "  ./reset_pipeline.sh from N     - Reset from step N onwards"
    echo ""
    echo "Example:"
    echo "  ./reset_pipeline.sh from 4     - Re-run from step 4 onwards"
fi
