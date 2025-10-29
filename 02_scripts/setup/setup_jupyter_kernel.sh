#!/bin/bash
# setup_jupyter_kernel.sh - Register project venv as Jupyter kernel

echo "=== SETUP JUPYTER KERNEL FROM PROJECT VENV ==="
echo ""

# Xác định đường dẫn
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
KERNEL_NAME="final_project"

echo "Root directory: $ROOT_DIR"
echo "Venv directory: $VENV_DIR"
echo ""

# Kiểm tra venv tồn tại
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment không tồn tại tại: $VENV_DIR"
    echo "   Vui lòng tạo venv trước:"
    echo "   python -m venv .venv"
    echo "   # hoặc: uv venv"
    exit 1
fi

echo "✅ Đã tìm thấy virtual environment"
echo ""

# Kích hoạt venv
source "$VENV_DIR/bin/activate"

# Kiểm tra ipykernel đã cài chưa
if ! python -c "import ipykernel" 2>/dev/null; then
    echo "📦 Đang cài ipykernel..."
    pip install ipykernel
fi

# Register kernel
echo "🔧 Đang register kernel '$KERNEL_NAME'..."
python -m ipykernel install --user --name="$KERNEL_NAME" --display-name="Python (Final Project)"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================"
    echo "✅ HOÀN TẤT SETUP KERNEL!"
    echo "================================"
    echo ""
    echo "Kernel name: $KERNEL_NAME"
    echo "Display name: Python (Final Project)"
    echo ""
    echo "📝 Cách sử dụng:"
    echo "   1. Khởi động Jupyter Lab:"
    echo "      jupyter lab"
    echo ""
    echo "   2. Mở notebook: 06_visualizations/analysis_notebook.ipynb"
    echo ""
    echo "   3. Click vào kernel selector (góc trên bên phải)"
    echo "      Chọn: 'Python (Final Project)'"
    echo ""
    echo "💡 Hoặc trong notebook, chọn menu:"
    echo "   Kernel → Change Kernel → Python (Final Project)"
    echo ""
else
    echo "❌ Lỗi khi register kernel"
    exit 1
fi
