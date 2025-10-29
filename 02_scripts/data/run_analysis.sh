#!/bin/bash
# run_analysis.sh - Execute Jupyter notebook from terminal

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
NOTEBOOK_PATH="$ROOT_DIR/06_visualizations/analysis_notebook.ipynb"
OUTPUT_PATH="$ROOT_DIR/06_visualizations/analysis_output_$(date +%Y%m%d_%H%M%S).ipynb"
KERNEL_NAME="final_project"

echo "=== EXECUTING JUPYTER NOTEBOOK FROM TERMINAL ==="
echo ""
echo "Notebook: $NOTEBOOK_PATH"
echo "Output: $OUTPUT_PATH"
echo "Kernel: $KERNEL_NAME"
echo ""

# Activate venv
source "$ROOT_DIR/.venv/bin/activate"

# Check if jupyter is installed
if ! command -v jupyter &> /dev/null; then
    echo "❌ Jupyter not found. Please install:"
    echo "   pip install jupyter"
    exit 1
fi

# Check if kernel exists
if ! jupyter kernelspec list | grep -q "$KERNEL_NAME"; then
    echo "❌ Kernel '$KERNEL_NAME' not found."
    echo "   Please run setup script first:"
    echo "   ./02_scripts/setup/setup_jupyter_kernel.sh"
    exit 1
fi

echo "🚀 Executing notebook..."
echo ""

# Execute notebook
jupyter nbconvert --to notebook --execute \
    --ExecutePreprocessor.kernel_name="$KERNEL_NAME" \
    --ExecutePreprocessor.timeout=3600 \
    --output="$OUTPUT_PATH" \
    "$NOTEBOOK_PATH"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================"
    echo "✅ NOTEBOOK EXECUTED SUCCESSFULLY!"
    echo "================================"
    echo ""
    echo "Output saved to: $OUTPUT_PATH"
    echo ""
    echo "📊 Generated files in 06_visualizations/:"
    ls -lh "$ROOT_DIR/06_visualizations/" | grep -E "\.csv|\.ipynb" | tail -5
    echo ""
else
    echo ""
    echo "❌ Notebook execution failed!"
    exit 1
fi
