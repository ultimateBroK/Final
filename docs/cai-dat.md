# 🚀 INSTALLATION GUIDE

Hướng dẫn cài đặt môi trường cho dự án Money Laundering Detection.

---

## 📋 Yêu cầu hệ thống

### Hardware
- **RAM:** ≥ 16GB (khuyến nghị 32GB)
- **Disk:** ≥ 50GB trống
- **CPU:** Multi-core (4+ cores khuyến nghị)

### Software
- **OS:** Linux (CachyOS/Arch hoặc Ubuntu/Debian)
- **Python:** 3.10+
- **Java:** 11 hoặc 17 (cho Hadoop/Spark)
- **HDFS:** Hadoop 3.x

---

## 🔧 Cài đặt từng bước

### 1. Cài đặt UV Package Manager (Khuyến nghị)

**UV** là package manager cực nhanh cho Python, thay thế pip.

```bash
# Cài UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Hoặc với pacman (Arch/CachyOS)
sudo pacman -S uv

# Reload shell
source ~/.zshrc

# Kiểm tra
uv --version
```

### 2. Setup Project với UV

```bash
# Di chuyển đến thư mục project
cd /home/ultimatebrok/Downloads/Final

# Tạo virtual environment với UV (tự động)
uv venv

# Kích hoạt
source .venv/bin/activate

# Cài tất cả dependencies (CỰC NHANH!)
uv pip install -r requirements.txt

# Kiểm tra
python -c "import polars, pyspark, plotly; print('✅ All packages installed!')"
```

### 3. (Alternative) Sử dụng pip truyền thống

Nếu không muốn dùng UV:

```bash
# Tạo venv
python -m venv .venv
source .venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Cài dependencies
pip install -r requirements.txt
```

### 4. Apache Spark

```bash
# Chạy installation script
./scripts/setup/install_spark.sh

# Reload shell
source ~/.zshrc

# Kiểm tra
spark-submit --version
```

### 5. Hadoop/HDFS Setup

#### Option A: Standalone HDFS (khuyến nghị cho development)

```bash
# Arch/CachyOS
sudo pacman -S hadoop

# Ubuntu/Debian
sudo apt install hadoop
```

#### Option B: Spark local mode (không cần HDFS)

Spark có thể chạy local mode mà không cần HDFS cluster.

---

## ✅ Kiểm tra cài đặt

### Python packages

```bash
python << EOF
import polars as pl
import numpy as np
import pyspark
import plotly
import matplotlib
import seaborn

print("✅ Polars:", pl.__version__)
print("✅ NumPy:", np.__version__)
print("✅ PySpark:", pyspark.__version__)
print("✅ Plotly:", plotly.__version__)
print("✅ All packages OK!")
EOF
```

### Jupyter

```bash
# Kiểm tra Jupyter Lab
jupyter lab --version

# Khởi động (test)
jupyter lab --no-browser --port=8888
# Ctrl+C để thoát
```

### HDFS (nếu dùng)

```bash
# Khởi động HDFS
start-dfs.sh

# Kiểm tra
hdfs dfsadmin -report

# Dừng
stop-dfs.sh
```

---

## 📦 Dependencies chi tiết

### Core Data Processing
| Package | Version | Mục đích |
|---------|---------|----------|
| polars | ≥0.19.0 | Fast DataFrame operations |
| numpy | ≥1.24.0 | Numerical computing |
| pandas | ≥2.1.0 | Data manipulation |
| pyarrow | ≥14.0.0 | Columnar format |

### Big Data
| Package | Version | Mục đích |
|---------|---------|----------|
| pyspark | ≥3.5.0 | Distributed computing |

### Jupyter
| Package | Version | Mục đích |
|---------|---------|----------|
| jupyter | ≥1.0.0 | Notebook environment |
| jupyterlab | ≥4.0.0 | Modern interface |
| notebook | ≥7.0.0 | Classic notebook |
| ipywidgets | ≥8.0.0 | Interactive widgets |

### Visualization
| Package | Version | Mục đích |
|---------|---------|----------|
| plotly | ≥5.17.0 | Interactive plots |
| kaleido | ≥0.2.1 | Static export |
| matplotlib | ≥3.8.0 | Static plots |
| seaborn | ≥0.13.0 | Statistical viz |

---

## 🔧 Troubleshooting

### Lỗi: pip install fails

**Nguyên nhân:** Thiếu build tools

```bash
# Arch/CachyOS
sudo pacman -S base-devel python-pip

# Ubuntu/Debian
sudo apt install build-essential python3-dev
```

### Lỗi: PySpark không tìm thấy Java

**Giải pháp:**

```bash
# Kiểm tra Java
java -version

# Nếu chưa có, cài Java 11
sudo pacman -S jdk11-openjdk  # Arch
sudo apt install openjdk-11-jdk  # Ubuntu

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' >> ~/.zshrc
```

### Lỗi: Jupyter Lab không khởi động

**Giải pháp:**

```bash
# Rebuild Jupyter Lab
jupyter lab clean
jupyter lab build

# Cài lại
pip install --upgrade --force-reinstall jupyterlab
```

### Lỗi: Plotly không hiển thị trong Jupyter

**Giải pháp:**

```bash
# Cài extension
jupyter labextension install jupyterlab-plotly

# Hoặc dùng renderer
python -c "import plotly.io as pio; pio.renderers.default='notebook'"
```

### Lỗi: Out of memory khi cài packages

**Giải pháp:**

```bash
# Cài từng package một
pip install polars
pip install pyspark
pip install plotly
# ...
```

---

## 🎯 Workflows cài đặt

### ⚡ Quick Install với UV (Khuyến nghị - CỰC NHANH!)

```bash
cd /home/ultimatebrok/Downloads/Final

# Cài UV (nếu chưa có)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.zshrc

# Setup trong 2 lệnh!
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt

# Test
python -c "import polars, pyspark, plotly; print('✅ OK!')"
```

### 🐢 Quick Install với pip (Traditional)

```bash
cd /home/ultimatebrok/Downloads/Final
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 🚀 Full Install với UV (từ đầu)

```bash
# 1. Cài UV, Python & Java
curl -LsSf https://astral.sh/uv/install.sh | sh
sudo pacman -S python jdk11-openjdk  # Arch/CachyOS
# sudo apt install python3 openjdk-11-jdk  # Ubuntu

# 2. Reload shell
source ~/.zshrc

# 3. Navigate to project
cd /home/ultimatebrok/Downloads/Final

# 4. Setup với UV
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt

# 5. Cài Spark (optional)
./scripts/setup/install_spark.sh
source ~/.zshrc

# 6. Test
python -c "import polars, pyspark, plotly; print('✅ OK!')"
```

---

## 📚 Tài liệu liên quan

- [README.md](README.md) - Tổng quan project
- [CAU_TRUC_DU_AN.md](CAU_TRUC_DU_AN.md) - Cấu trúc thư mục
- [HUONG_DAN_CHAY.md](HUONG_DAN_CHAY.md) - Hướng dẫn chạy pipeline

---

## 💡 Tips

### UV vs pip - So sánh tốc độ

| Task | pip | UV | Tốc độ |
|------|-----|----|---------|
| Install all deps | ~5-10 phút | ~30-60 giây | **10-20x nhanh hơn** |
| Resolve dependencies | Chậm | Rất nhanh | **Instant** |
| Cache | Limited | Excellent | **Efficient** |

### UV Commands

```bash
# Tạo venv
uv venv

# Cài packages
uv pip install package_name
uv pip install -r requirements.txt

# Upgrade packages
uv pip install --upgrade package_name

# Sync dependencies (giống pip-compile)
uv pip sync requirements.txt

# List installed packages
uv pip list

# Uninstall
uv pip uninstall package_name
```

### Virtual Environment Best Practices

```bash
# Kích hoạt tự động khi cd vào folder (zsh)
echo 'cd() { builtin cd "$@" && [ -f .venv/bin/activate ] && source .venv/bin/activate }' >> ~/.zshrc

# Deactivate
deactivate
```

### Upgrade packages

```bash
# Với UV (khuyến nghị)
uv pip install --upgrade -r requirements.txt
uv pip install --upgrade polars pyspark plotly

# Với pip
pip install --upgrade -r requirements.txt
pip install --upgrade polars pyspark plotly
```

### Export current environment

```bash
# Với UV
uv pip freeze > requirements_freeze.txt

# Với pip
pip freeze > requirements_freeze.txt
```

---

**Cập nhật:** 2025-10-29  
**Hỗ trợ:** Xem [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) nếu cần
