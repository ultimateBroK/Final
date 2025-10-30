#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BƯỚC 4: THUẬT TOÁN K-MEANS VỚI SPARK MLlib (TỐI ƯU)

Pipeline 7 bước:
  1) Khám phá dữ liệu
  2) Chuẩn bị đặc trưng
  3) Tải lên HDFS
  4) K-means MLlib <- Bước này
  5) Tải kết quả
  6) Gán nhãn cụm
  7) Phân tích

Mục đích:
- Chạy K-means trên dữ liệu lớn (179M dòng)
- Dùng Spark MLlib (Catalyst + Tungsten), khởi tạo k-means++ (k-means||)
- Lưu trên HDFS để tuân thủ bảo mật
"""

import sys
import time
from datetime import datetime
from pyspark.sql import SparkSession
from pyspark.ml.clustering import KMeans
from pyspark.ml.feature import VectorAssembler
from pyspark import StorageLevel
import numpy as np

def run_kmeans(input_path: str, output_path: str, k: int = 5, max_iter: int = 15, seed: int = 42, tol: float = 1e-4) -> None:
    """Chạy K-means với Spark MLlib trên dữ liệu CSV không có header (HDFS)."""
    
    # Khởi tạo Spark với MLlib optimization
    spark = SparkSession.builder \
        .appName("K-means MLlib - Optimized") \
        .config("spark.driver.memory", "8g") \
        .config("spark.executor.memory", "8g") \
        .config("spark.executor.instances", "4") \
        .config("spark.executor.cores", "4") \
        .config("spark.sql.shuffle.partitions", "800") \
        .config("spark.default.parallelism", "800") \
        .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
        .config("spark.kryoserializer.buffer.max", "512m") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.hadoop.fs.defaultFS", "hdfs://localhost:9000") \
        .getOrCreate()
    
    sc = spark.sparkContext
    # Thiết lập log level WARN để tắt TaskSetManager, executor details
    sc.setLogLevel("WARN")
    
    # Gợi ý giảm ồn log mức INFO (tùy phiên bản Spark)
    log4j = sc._jvm.org.apache.log4j
    log4j.LogManager.getLogger("org.apache.spark").setLevel(log4j.Level.WARN)
    
    # Helper function for timestamps
    def log_with_time(msg, step_start=None):
        current_time = datetime.now().strftime("%H:%M:%S")
        if step_start:
            elapsed = time.time() - step_start
            print(f"[{current_time}] {msg} (mất {elapsed:.1f}s)")
        else:
            print(f"[{current_time}] {msg}")
    
    pipeline_start = time.time()
    
    print("=" * 70)
    print("SPARK MLlib K-means - Chế độ tối ưu")
    print("=" * 70)
    log_with_time(f"Đầu vào: {input_path}")
    log_with_time(f"Số cụm: {k}")
    log_with_time(f"Số lần lặp tối đa: {max_iter}")
    log_with_time("Khởi tạo k-means++")
    log_with_time("Tối ưu hóa Catalyst + Tungsten")
    print()
    
    # Đọc dữ liệu từ HDFS
    step_start = time.time()
    log_with_time("Bước 1/5: Đọc dữ liệu từ HDFS...")
    df = spark.read.csv(
        input_path,
        header=False,
        inferSchema=True
    )
    
    # Đổi tên cột
    num_cols = len(df.columns)
    df = df.toDF(*[f'f{i}' for i in range(num_cols)])
    
    data_count = df.count()
    log_with_time(f"Đã tải {data_count:,} bản ghi", step_start)
    print()
    
    # Chuyển đổi sang vector
    step_start = time.time()
    log_with_time("Bước 2/5: Tạo vector đặc trưng...")
    assembler = VectorAssembler(
        inputCols=[f for f in df.columns],
        outputCol="features"
    )
    vector_df = assembler.transform(df).select("features")
    
    # Cache để tăng tốc
    log_with_time("   Lưu đệm vào bộ nhớ/đĩa...")
    vector_df = vector_df.persist(StorageLevel.MEMORY_AND_DISK)
    
    vec_count = vector_df.count()
    log_with_time(f"Đã tạo {vec_count:,} vector đặc trưng", step_start)
    print()
    
    # Khởi tạo K-means với k-means++ (k-means||)
    step_start = time.time()
    log_with_time("Bước 3/5: Cấu hình K-means (k-means++)...")
    kmeans = KMeans() \
        .setK(k) \
        .setMaxIter(max_iter) \
        .setInitMode("k-means||") \
        .setFeaturesCol("features") \
        .setPredictionCol("cluster") \
        .setSeed(seed) \
        .setTol(tol)

    log_with_time(f"   Đã cấu hình: K={k}, MaxIter={max_iter}, Seed={seed}, Tol={tol}", step_start)
    print()
    
    # Huấn luyện
    train_start = time.time()
    log_with_time("Bước 4/5: Đang huấn luyện K-means...")
    log_with_time("   Sử dụng Catalyst + Tungsten; vui lòng đợi...")
    print()
    
    # Huấn luyện mô hình
    model = kmeans.fit(vector_df)

    log_with_time("Hoàn thành huấn luyện K-means! ✅", train_start)
    
    # Lấy centroids
    centroids = model.clusterCenters()
    
    # Thống kê về quá trình training
    summary = getattr(model, 'summary', None)
    num_iterations = getattr(summary, 'numIter', "N/A")
    training_cost = getattr(summary, 'trainingCost', None)
    
    print()
    print("=" * 70)
    log_with_time("Hoàn thành phân cụm K-means! ✅")
    print("=" * 70)
    print()
    print("Thông tin huấn luyện:")
    print(f"   - Số vòng lặp thực tế: {num_iterations}")
    print(f"   - Số vòng lặp tối đa: {max_iter}")
    if training_cost is not None:
        print(f"   - WSSSE (Within-Set SSE): {training_cost:.2f}")
    print()
    
    # Lưu tâm cụm vào HDFS
    step_start = time.time()
    log_with_time(f"Bước 5/5: Lưu {len(centroids)} tâm cụm vào HDFS...")
    log_with_time(f"   Đường dẫn: {output_path}")
    
    # Chuyển centroids thành text format
    centroids_lines = [','.join(f'{x:.6f}' for x in row) for row in centroids]
    centroids_rdd = sc.parallelize(centroids_lines, 1)
    # Ghi đè thư mục kết quả nếu tồn tại
    try:
        sc._jsc.hadoopConfiguration().set("dfs.client.block.write.replace-datanode-on-failure.policy", "ALWAYS")
        sc._jsc.hadoopConfiguration().set("dfs.client.block.write.replace-datanode-on-failure.enable", "true")
        # Xóa thư mục cũ nếu có
        sc._jvm.org.apache.hadoop.fs.FileSystem.get(sc._jsc.hadoopConfiguration()).delete(sc._jvm.org.apache.hadoop.fs.Path(output_path), True)
    except Exception:
        pass
    centroids_rdd.saveAsTextFile(output_path)
    
    log_with_time("Đã lưu tâm cụm", step_start)
    print()
    
    # Tính toán phân cụm cuối cùng
    step_start = time.time()
    log_with_time("Phân tích kết quả...")
    predictions = model.transform(vector_df)
    
    # Đếm số điểm mỗi cụm
    cluster_counts = predictions.groupBy("cluster").count().collect()
    
    log_with_time("Đã phân tích xong", step_start)
    print()
    print("📊 Phân phối cụm:")
    total_points = data_count
    for row in sorted(cluster_counts, key=lambda r: r["cluster"]):
        cid = row["cluster"]
        count = row["count"]
        percentage = (count / total_points) * 100 if total_points else 0.0
        bar = '█' * max(1, int(percentage / 2))
        print(f"   - Cụm {cid}: {count:,} điểm ({percentage:.2f}%) {bar}")
    
    if training_cost is not None and total_points:
        print()
        print("Chỉ số chất lượng cụm:")
        print(f"   - WSSSE: {training_cost:.2f}")
        print(f"   - Trung bình SSE/điểm: {training_cost/total_points:.6f}")
    
    # Tổng kết thời gian
    total_time = time.time() - pipeline_start
    print()
    print("=" * 70)
    log_with_time("Hoàn thành toàn bộ tiến trình!")
    log_with_time(f"Tổng thời gian: {total_time/60:.1f} phút ({total_time:.1f}s)")
    print("=" * 70)
    print()
    
    # Unpersist
    vector_df.unpersist()
    
    spark.stop()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Cách dùng: spark-submit kmeans_spark.py <hdfs_input> <hdfs_output> [k] [max_iter] [seed] [tol]")
        print("Ví dụ: spark-submit kmeans_spark.py hdfs://localhost:9000/user/spark/hi_large/input/hadoop_input.txt hdfs://localhost:9000/user/spark/hi_large/output_centroids 5 15 42 1e-4")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    # Mặc định
    k = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    max_iterations = int(sys.argv[4]) if len(sys.argv) > 4 else 15
    seed = int(sys.argv[5]) if len(sys.argv) > 5 else 42
    tol = float(sys.argv[6]) if len(sys.argv) > 6 else 1e-4

    print(f"📥 HDFS đầu vào: {input_path}")
    print(f"📤 HDFS đầu ra: {output_path}")
    print(f"🔢 Số cụm K: {k}")
    print(f"🔁 Số lần lặp tối đa: {max_iterations}")
    print(f"🌱 Seed: {seed}")
    print(f"🎯 Tol: {tol}")
    print()

    run_kmeans(input_path, output_path, k, max_iterations, seed, tol)
