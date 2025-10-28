# Polars + Hadoop Pipeline

Pipeline phân tích dữ liệu HI-Large_Trans.csv sử dụng Polars và Hadoop MapReduce.

## Cấu trúc thư mục (ADHD-friendly)

```
data/
  raw/                # Input gốc (CSV lớn)
  processed/          # Đầu vào/ra trung gian cho Hadoop
  results/            # Kết quả cuối
docs/                 # Tài liệu
logs/                 # Log pipeline
scripts/
  hadoop/             # Mapper/Reducer + runner
```

## Chuẩn bị dữ liệu

- Đặt file CSV vào: `data/raw/HI-Large_Trans.csv`

## Chạy Pipeline

```bash
./scripts/full_pipeline.sh
```

Log sẽ lưu tại `logs/pipeline_log_*.md`.

## Clean Outputs

```bash
./scripts/clean_outputs.sh
./scripts/full_pipeline.sh
```

## Các File Output (local)

- `data/processed/hadoop_input.txt`
- `data/processed/centroids.txt`
- `data/processed/centroids_new.txt`
- `data/processed/final_centroids.txt`
- `data/results/clustered_results.txt`

## HDFS directories

- `/user/hadoop/hi_large/input/`
- `/user/hadoop/hi_large/output_iter_*`
- `/user/hadoop/hi_large/centroids.txt`

## Pipeline Steps

1. `scripts/explore_fast.py`
2. `scripts/prepare_polars.py`
3. `scripts/init_centroids.py`
4. `scripts/hadoop/run_hadoop_optimized.sh`
5. `scripts/assign_clusters_polars.py`
6. `scripts/analyze_polars.py`
