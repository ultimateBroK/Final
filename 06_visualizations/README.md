# 📊 Visualization với Jupyter Notebook

Hướng dẫn setup và sử dụng Jupyter Notebook để phân tích kết quả clustering.

---

## 🚀 Setup

### 1. Cài đặt dependencies

```bash
# Từ thư mục root của project
cd /home/ultimatebrok/Downloads/Final

# Kích hoạt virtual environment (nếu có)
source .venv/bin/activate

# Cài đặt tất cả dependencies (bao gồm visualization)
pip install -r requirements.txt
```

### 2. Khởi động Jupyter

```bash
# Option 1: Jupyter Notebook (classic)
jupyter notebook

# Option 2: JupyterLab (modern, khuyến nghị)
jupyter lab

# Hoặc chỉ định port cụ thể
jupyter lab --port=8888
```

### 3. Mở notebook

Trong browser, navigate đến:
```
06_visualizations/analysis_notebook.ipynb
```

---

## 📚 Notebooks có sẵn

### `analysis_notebook.ipynb`
**Mục đích:** Phân tích toàn diện kết quả clustering

**Nội dung:**
1. **Setup & Imports** - Load libraries
2. **Load Data** - Đọc CSV và cluster results
3. **Basic Statistics** - Thống kê tổng quan
4. **Cluster Distribution** - Phân phối clusters
5. **Money Laundering Analysis** - Phân tích rửa tiền
6. **Feature Analysis** - Phân tích features theo cluster
7. **Temporal Analysis** - Phân tích theo thời gian
8. **Centroids Visualization** - Heatmap của centroids
9. **Summary Report** - Báo cáo tổng kết
10. **Export Results** - Xuất kết quả

**Visualizations:**
- 📊 Interactive bar charts (Plotly)
- 📈 Line charts cho temporal patterns
- 🎯 Heatmaps cho centroids
- 🔥 Color-coded risk levels

---

## 🎨 Thư viện visualization

### Plotly (Interactive)
```python
import plotly.express as px
import plotly.graph_objects as go

# Bar chart
fig = px.bar(df, x='cluster', y='count', color='laundering_rate')
fig.show()
```

**Ưu điểm:**
- Interactive (zoom, pan, hover)
- Export sang HTML
- Đẹp, professional

### Matplotlib + Seaborn (Static)
```python
import matplotlib.pyplot as plt
import seaborn as sns

# Heatmap
sns.heatmap(data, annot=True, cmap='RdBu')
plt.show()
```

**Ưu điểm:**
- Standard, familiar
- Nhiều options
- Export PNG/PDF

---

## 💡 Tips & Tricks

### 1. Working với dữ liệu lớn

```python
# Dùng lazy loading
df = pl.scan_csv('data.csv')

# Sample cho visualization
df_sample = df.sample(n=100_000, seed=42).collect()

# Hoặc dùng streaming
for batch in df.iter_slices(n_rows=10_000):
    # Process batch
    pass
```

### 2. Memory management

```python
import gc

# Sau khi xong với dataframe lớn
del df
gc.collect()
```

### 3. Export visualizations

```python
# Plotly -> HTML
fig.write_html('chart.html')

# Plotly -> PNG (cần kaleido)
fig.write_image('chart.png')

# Matplotlib -> PNG
plt.savefig('chart.png', dpi=300, bbox_inches='tight')
```

### 4. Dark theme cho Plotly

```python
import plotly.io as pio
pio.templates.default = "plotly_dark"
```

---

## 🔧 Troubleshooting

### Lỗi: "Out of memory"
**Giải pháp:**
```python
# Sample data thay vì load toàn bộ
df_sample = df.sample(fraction=0.1)  # 10% data

# Hoặc giới hạn số cột
df_subset = df.select(['cluster', 'Is Laundering', 'Amount Received'])
```

### Lỗi: Jupyter kernel dies
**Giải pháp:**
```bash
# Tăng memory limit
export JUPYTER_CONFIG_DIR=~/.jupyter
echo "c.NotebookApp.max_buffer_size = 1073741824" >> ~/.jupyter/jupyter_notebook_config.py

# Hoặc khởi động với memory limit cao hơn
jupyter lab --ServerApp.max_buffer_size=1073741824
```

### Lỗi: Plotly không hiển thị
**Giải pháp:**
```bash
# Cài extension cho JupyterLab
jupyter labextension install jupyterlab-plotly
```

---

## 📖 Tài liệu tham khảo

### Polars
- Docs: https://pola-rs.github.io/polars/
- API: https://pola-rs.github.io/polars/py-polars/html/reference/

### Plotly
- Docs: https://plotly.com/python/
- Gallery: https://plotly.com/python/plotly-express/

### Jupyter
- Docs: https://jupyter.org/documentation
- Tips: https://jupyter-notebook.readthedocs.io/

---

## 🎯 Workflow đề xuất

```bash
# 1. Chạy pipeline
./02_scripts/pipeline/full_pipeline_spark.sh

# 2. Khởi động Jupyter
jupyter lab

# 3. Mở notebook và chạy
# 06_visualizations/analysis_notebook.ipynb

# 4. Export results
# Trong notebook: Run "Export Results" cell

# 5. Share
# Copy HTML files hoặc export PNG
```

---

## 📊 Output Files

Sau khi chạy notebook, các files sẽ được tạo trong `06_visualizations/`:

```
06_visualizations/
├── analysis_notebook.ipynb
├── cluster_statistics.csv       # Thống kê clusters
├── high_risk_transactions.csv   # Giao dịch rủi ro cao (nếu có)
└── README.md                     # File này
```

---

**Happy Analyzing! 🎉**
