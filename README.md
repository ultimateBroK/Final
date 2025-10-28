# Polars + Hadoop Pipeline

Pipeline phân tích dữ liệu HI-Large_Trans.csv sử dụng Polars và Hadoop MapReduce.

## Chạy Pipeline

```bash
./full_pipeline.sh
```

## Clean Outputs

Để xóa tất cả outputs và chạy lại pipeline từ đầu:

```bash
./clean_outputs.sh
./full_pipeline.sh
```

## Các File Output

Pipeline sẽ tạo các files sau:

**Local files:**
- `hadoop_input.txt` - Dữ liệu đã được chuẩn hóa cho Hadoop
- `centroids.txt` - Centroids hiện tại (được update mỗi iteration)
- `centroids_new.txt` - Centroids mới từ iteration hiện tại
- `final_centroids.txt` - Centroids cuối cùng sau khi converged
- `clustered_results.txt` - Kết quả phân cụm cho mỗi transaction

**HDFS directories:**
- `/user/hadoop/hi_large/input/` - Input data trên HDFS
- `/user/hadoop/hi_large/output_iter_*` - Output từ mỗi MapReduce iteration
- `/user/hadoop/hi_large/centroids.txt` - Centroids trên HDFS

## Pipeline Steps

1. **explore_fast.py** - Khám phá dữ liệu
2. **prepare_polars.py** - Chuẩn bị features với Polars
3. **init_centroids.py** - Khởi tạo centroids
4. **run_hadoop_optimized.sh** - Chạy K-means với Hadoop MapReduce
5. **assign_clusters_polars.py** - Gán clusters cho tất cả transactions
6. **analyze_polars.py** - Phân tích kết quả
