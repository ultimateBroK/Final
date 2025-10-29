#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BƯỚC 4: THUẬT TOÁN K-MEANS VỚI SPARK MLLIB (TỐI ƯU HƠN)

Pipeline 7 bước hiện tại:
  1. Khám phá dữ liệu
  2. Chuẩn bị đặc trưng
  3. Upload lên HDFS
  4. K-means MLlib <- BƯỚC NÀY
  5. Tải kết quả
  6. Gán nhãn cụm
  7. Phân tích

Mục đích:
- Chạy thuật toán K-means clustering trên dữ liệu lớn (179M dòng)
- Sử dụng Spark MLlib - tối ưu hóa bởi Catalyst optimizer + Tungsten
- K-means++ initialization (k-means||) - hội tụ nhanh hơn
- Lưu trữ dữ liệu trên HDFS để tuân thủ quy định bảo mật

Thời gian chạy: ~10-15 phút (nhanh hơn 30-50% so với custom RDD)
Input:
  - HDFS: /user/spark/hi_large/input/hadoop_input.txt (33GB)
Output: HDFS: /user/spark/hi_large/output_centroids (5 tâm cụm cuối cùng)

Kỹ thuật: Spark MLlib KMeans, k-means++ init, adaptive execution
"""

import sys
import time
from datetime import datetime
from pyspark.sql import SparkSession
from pyspark.ml.clustering import KMeans
from pyspark.ml.feature import VectorAssembler
from pyspark import StorageLevel

def run_kmeans(input_path, output_path, k=5, max_iterations=15, seed=42, tol=1e-4, use_hdfs=True):
    """
    Chạy thuật toán K-means clustering với Spark MLlib
    
    Args:
        input_path: Đường dẫn HDFS đến dữ liệu đầu vào (CSV không có header)
        output_path: Đường dẫn HDFS để lưu tâm cụm cuối cùng
        k: Số cụm (default=5)
        max_iterations: Số lần lặp tối đa (default=15)
        use_hdfs: Có sử dụng HDFS hay không (mặc định True)
    """
    
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
    sc.setLogLevel("WARN")
    
    # Helper function for timestamps
    def log_with_time(msg, step_start=None):
        current_time = datetime.now().strftime("%H:%M:%S")
        if step_start:
            elapsed = time.time() - step_start
            print(f"[{current_time}] {msg} (⏱️  {elapsed:.1f}s)")
        else:
            print(f"[{current_time}] {msg}")
    
    pipeline_start = time.time()
    
    print("=" * 70)
    print("🚀 SPARK MLLIB K-MEANS - TĂNG TỐC EDITION")
    print("=" * 70)
    log_with_time(f"📅 Đầu vào: {input_path}")
    log_with_time(f"📊 Số cụm: {k}")
    log_with_time(f"🔄 Số lần lặp tối đa: {max_iterations}")
    log_with_time("✅ K-means++ initialization")
    log_with_time("✅ Catalyst optimizer + Tungsten")
    print()
    
    # Đọc dữ liệu từ HDFS
    step_start = time.time()
    log_with_time("📂 BƯỚC 1/5: Đang đọc dữ liệu từ HDFS...")
    df = spark.read.csv(
        input_path,
        header=False,
        inferSchema=True
    )
    
    # Đổi tên cột
    num_cols = len(df.columns)
    df = df.toDF(*[f'f{i}' for i in range(num_cols)])
    
    data_count = df.count()
    log_with_time(f"✅ Đã load {data_count:,} điểm dữ liệu", step_start)
    print()
    
    # Chuyển đổi sang vector features
    step_start = time.time()
    log_with_time("🔧 BƯỚC 2/5: Chuyển đổi sang feature vectors...")
    assembler = VectorAssembler(
        inputCols=df.columns,
        outputCol="features"
    )
    vector_df = assembler.transform(df).select("features")
    
    # Cache để tăng tốc
    log_with_time("   💾 Caching data vào memory/disk...")
    vector_df = vector_df.persist(StorageLevel.MEMORY_AND_DISK)
    
    vec_count = vector_df.count()
    log_with_time(f"✅ Đã tạo {vec_count:,} feature vectors", step_start)
    print()
    
    # Khởi tạo K-means với k-means++ (k-means||)
    step_start = time.time()
    log_with_time("🎯 BƯỚC 3/5: Khởi tạo K-means với k-means++ initialization...")
    kmeans = KMeans() \
        .setK(k) \
        .setMaxIter(max_iterations) \
        .setInitMode("k-means||") \
        .setFeaturesCol("features") \
        .setPredictionCol("cluster") \
        .setSeed(seed) \
        .setTol(tol)
    
    log_with_time(f"   ✅ Model configured: K={k}, MaxIter={max_iterations}, Seed={seed}, Tol={tol}", step_start)
    print()
    
    # Train model
    train_start = time.time()
    log_with_time(f"🚀 BƯỚC 4/5: Đang train K-means (tối đa {max_iterations} iterations)...")
    log_with_time("   💻 Sử dụng Catalyst optimizer + Tungsten execution engine")
    log_with_time("   ⌛ Vui lòng đợi 10-15 phút (phụ thuộc phần cứng)...")
    print()
    
    model = kmeans.fit(vector_df)
    
    log_with_time("✅ K-means training hoàn thành!", train_start)
    
    # Lấy centroids
    centroids = model.clusterCenters()
    
    print()
    print("=" * 70)
    log_with_time("✅ HOÀN THÀNH K-MEANS CLUSTERING!")
    print("=" * 70)
    print()
    
    # Lưu centroids vào HDFS
    step_start = time.time()
    log_with_time(f"💾 BƯỚC 5/5: Lưu {len(centroids)} tâm cụm vào HDFS...")
    log_with_time(f"   📍 Path: {output_path}")
    
    # Chuyển centroids thành text format
    centroids_lines = [','.join(f'{x:.6f}' for x in row) for row in centroids]
    centroids_rdd = sc.parallelize(centroids_lines, 1)
    centroids_rdd.saveAsTextFile(output_path)
    
    log_with_time("✅ Đã lưu tâm cụm", step_start)
    print()
    
    # Tính toán phân cụm cuối cùng
    step_start = time.time()
    log_with_time("📊 PHÂN TÍCH KẾT QUẢ...")
    predictions = model.transform(vector_df)
    
    # Đếm số điểm mỗi cụm
    cluster_counts = predictions.groupBy("cluster").count().collect()
    cluster_counts = sorted(cluster_counts, key=lambda r: r.cluster)
    
    log_with_time("✅ Đã phân tích xong", step_start)
    print()
    print("📊 PHÂN PHỐI CỤM:")
    for row in cluster_counts:
        count = row['count']
        percentage = (count / data_count) * 100
        print(f"   Cụm {row.cluster}: {count:,} điểm ({percentage:.2f}%)")
    
    # Tính Within Set Sum of Squared Errors (WSSSE)
    wssse = model.summary.trainingCost
    print()
    print(f"📈 WSSSE (Within-cluster SSE): {wssse:.2f}")
    print("   (Giá trị thấp hơn = cụm tốt hơn)")
    
    # Tổng kết thời gian
    total_time = time.time() - pipeline_start
    print()
    print("=" * 70)
    log_with_time("✅ HOÀN THÀNH TOÀN BỘ PIPELINE!")
    log_with_time(f"⏱️  Tổng thời gian: {total_time/60:.1f} phút ({total_time:.1f}s)")
    print("=" * 70)
    print()
    
    # Unpersist
    vector_df.unpersist()
    
    spark.stop()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Cách sử dụng: spark-submit kmeans_spark.py <đường_dẫn_hdfs_input> <đường_dẫn_hdfs_output> [k] [max_iter] [seed] [tol]")
        print("Ví dụ: spark-submit kmeans_spark.py hdfs://localhost:9000/user/spark/input.txt hdfs://localhost:9000/user/spark/output 5 15 42 1e-4")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    # Defaults
    k = 5
    max_iterations = 15
    seed = 42
    tol = 0.0001

    # Helper parsers that won't crash if order is flexible
    def try_parse_int(value):
        try:
            return int(value)
        except Exception:
            return None

    def try_parse_float(value):
        try:
            return float(value)
        except Exception:
            return None

    # Parse optional args with resilience to misordered inputs
    if len(sys.argv) > 3:
        k_candidate = try_parse_int(sys.argv[3])
        if k_candidate is not None and k_candidate > 0:
            k = k_candidate

    if len(sys.argv) > 4:
        # Prefer interpreting as max_iter if it is an int, otherwise maybe tol
        mi_candidate = try_parse_int(sys.argv[4])
        if mi_candidate is not None and mi_candidate > 0:
            max_iterations = mi_candidate
        else:
            tol_candidate = try_parse_float(sys.argv[4])
            if tol_candidate is not None and tol_candidate > 0:
                tol = tol_candidate

    if len(sys.argv) > 5:
        # Prefer seed (int); if not int, may be tol
        seed_candidate = try_parse_int(sys.argv[5])
        if seed_candidate is not None:
            seed = seed_candidate
        else:
            tol_candidate = try_parse_float(sys.argv[5])
            if tol_candidate is not None and tol_candidate > 0:
                tol = tol_candidate

    if len(sys.argv) > 6:
        tol_candidate = try_parse_float(sys.argv[6])
        if tol_candidate is not None and tol_candidate > 0:
            tol = tol_candidate

    print(f"HDFS Đầu vào: {input_path}")
    print(f"HDFS Đầu ra: {output_path}")
    print(f"Số cụm K: {k}")
    print(f"Max iterations: {max_iterations}")
    print(f"Seed: {seed}")
    print(f"Tol: {tol}")
    print()

    run_kmeans(input_path, output_path, k, max_iterations, seed, tol, use_hdfs=True)
