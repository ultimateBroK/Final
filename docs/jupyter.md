# 📓 JUPYTER SETUP - Sử dụng venv kernel

Hướng dẫn nhanh để chạy Jupyter notebook với kernel từ `.venv` của project.

---

## 🚀 Quick Start (3 bước)

### Bước 1: Setup kernel

```bash
cd /home/ultimatebrok/Downloads/Final

# Chạy script setup (tự động register kernel)
./scripts/setup/setup_jupyter_kernel.sh
```

### Bước 2: Khởi động Jupyter Lab

```bash
# Kích hoạt venv
source .venv/bin/activate

# Khởi động Jupyter Lab
jupyter lab
```

### Bước 3: Chọn kernel trong notebook

1. Mở notebook: `visualizations/analysis_notebook.ipynb`
2. Click vào kernel selector (góc trên phải)
3. Chọn: **"Python (Final Project)"**

✅ **Done!** Notebook giờ sử dụng packages từ `.venv`

---

## 📖 Giải thích chi tiết

### Tại sao cần register kernel?

Jupyter Lab cần biết về virtual environment của bạn. Mặc định, nó chỉ thấy Python system-wide.

**Trước register:**
```
Jupyter Lab → Python system → ❌ Không có polars, plotly, ...
```

**Sau register:**
```
Jupyter Lab → Python (Final Project) → ✅ Có tất cả packages trong .venv
```

### Script làm gì?

`setup_jupyter_kernel.sh` thực hiện:

1. Kiểm tra `.venv` tồn tại
2. Kích hoạt venv
3. Cài `ipykernel` (nếu chưa có)
4. Register kernel với tên "Python (Final Project)"

### Kernel được lưu ở đâu?

```
~/.local/share/jupyter/kernels/final_project/
```

Bạn có thể xem tất cả kernels:
```bash
jupyter kernelspec list
```

---

## 🔧 Manual Setup (nếu không dùng script)

```bash
# 1. Kích hoạt venv
cd /home/ultimatebrok/Downloads/Final
source .venv/bin/activate

# 2. Cài ipykernel (nếu chưa có)
pip install ipykernel

# 3. Register kernel
python -m ipykernel install --user --name=final_project --display-name="Python (Final Project)"

# 4. Khởi động Jupyter
jupyter lab
```

---

## 🎯 Kiểm tra kernel hoạt động

### Test trong notebook

Chạy cell này trong notebook:

```python
import sys
print("Python path:", sys.executable)
print("Should contain: .venv")

# Test packages
import polars
import plotly
import pyspark

print("\n✅ All packages available!")
print(f"Polars: {polars.__version__}")
print(f"Plotly: {plotly.__version__}")
print(f"PySpark: {pyspark.__version__}")
```

**Expected output:**
```
Python path: /home/ultimatebrok/Downloads/Final/.venv/bin/python
Should contain: .venv

✅ All packages available!
Polars: 0.19.x
Plotly: 5.17.x
PySpark: 3.5.x
```

---

## 🔧 Troubleshooting

### Lỗi: Kernel không xuất hiện

**Giải pháp:**

```bash
# Refresh kernel list
jupyter kernelspec list

# Restart Jupyter Lab
# Ctrl+C để dừng, rồi chạy lại
jupyter lab
```

### Lỗi: ModuleNotFoundError trong notebook

**Nguyên nhân:** Notebook đang dùng kernel sai

**Giải pháp:**

1. Click kernel selector
2. Chọn **"Python (Final Project)"**
3. Restart kernel (menu Kernel → Restart Kernel)

### Lỗi: ipykernel not found

**Giải pháp:**

```bash
source .venv/bin/activate
pip install ipykernel
```

### Xóa kernel (nếu cần reset)

```bash
jupyter kernelspec uninstall final_project
```

Sau đó chạy lại script setup.

---

## 💡 Tips & Tricks

### 1. Auto-activate venv khi cd

Thêm vào `~/.zshrc`:

```bash
cd() {
    builtin cd "$@"
    if [ -f .venv/bin/activate ]; then
        source .venv/bin/activate
    fi
}
```

### 2. Alias cho Jupyter

```bash
# Thêm vào ~/.zshrc
alias jlab='source .venv/bin/activate && jupyter lab'
alias jnb='source .venv/bin/activate && jupyter notebook'
```

Sau đó:
```bash
cd /home/ultimatebrok/Downloads/Final
jlab  # Tự động activate venv và start Jupyter
```

### 3. Chạy Jupyter ở background

```bash
# Start
nohup jupyter lab --no-browser > jupyter.log 2>&1 &

# URL sẽ ở trong jupyter.log
cat jupyter.log | grep "http://localhost"

# Stop
pkill -f "jupyter lab"
```

### 4. Remote access (nếu chạy trên server)

```bash
# Start với bind to all IPs
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser

# Access từ máy khác
# http://YOUR_SERVER_IP:8888
```

---

## 📊 Workflow đề xuất

### Daily workflow

```bash
# Morning
cd /home/ultimatebrok/Downloads/Final
source .venv/bin/activate
jupyter lab

# Work in notebook...
# visualizations/analysis_notebook.ipynb

# Evening
# Save work
# Ctrl+C to stop Jupyter
deactivate
```

### Pipeline → Analysis workflow

```bash
# 1. Chạy pipeline
./scripts/pipeline/full_pipeline_spark.sh

# 2. Start Jupyter
source .venv/bin/activate
jupyter lab

# 3. Analyze trong notebook
# Open: visualizations/analysis_notebook.ipynb
# Run all cells

# 4. Export results
# Notebook sẽ tạo files trong visualizations/
```

---

## 📚 Tài liệu liên quan

- [INSTALLATION.md](INSTALLATION.md) - Cài đặt dependencies
- [visualizations/README.md](visualizations/README.md) - Hướng dẫn visualization
- [requirements.txt](requirements.txt) - List packages

---

## 🆘 Cần giúp đỡ?

### Kiểm tra trạng thái

```bash
# Kernel có được register chưa?
jupyter kernelspec list

# Packages có đủ chưa?
source .venv/bin/activate
python -c "import polars, plotly, pyspark; print('✅ OK')"

# Jupyter có chạy được không?
jupyter lab --version
```

### Quick fix

```bash
# Reset everything
jupyter kernelspec uninstall final_project
rm -rf ~/.local/share/jupyter/kernels/final_project

# Setup lại
cd /home/ultimatebrok/Downloads/Final
./scripts/setup/setup_jupyter_kernel.sh
```

---

**Cập nhật:** 2025-10-29  
**Kernel name:** `final_project`  
**Display name:** `Python (Final Project)`
