#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BƯỚC 5: THUẬT TOÁN K-MEANS VỚI PYSPARK TRÊN HDFS

Mục đích:
- Chạy thuật toán K-means clustering trên dữ liệu lớn (179M dòng)
- Sử dụng PySpark để xử lý song song trên nhiều node
- Lưu trữ dữ liệu trên HDFS để tuân thủ quy định bảo mật
- Tìm 5 tâm cụm cuối cùng cho việc phân loại giao dịch

Thời gian chạy: ~30-60 phút
Input:
  - HDFS: /user/spark/hi_large/input/hadoop_input.txt (33GB)
  - HDFS: /user/spark/hi_large/centroids.txt (5 tâm cụm ban đầu)
Output: HDFS: /user/spark/hi_large/output_centroids (5 tâm cụm cuối cùng)

Kỹ thuật: MapReduce với PySpark, Broadcast variables
"""

import sys
import numpy as np
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf
from pyspark.sql.types import IntegerType, ArrayType, DoubleType
import os

def parse_point(line):
    """Chuyển đổi dòng CSV thành mảng numpy"""
    return np.array([float(x) for x in line.split(',')])

def closest_centroid(point, centroids_bc):
    """Tìm chỉ số của tâm cụm gần nhất"""
    centroids = centroids_bc.value
    point_arr = np.array(point)
    distances = np.linalg.norm(centroids - point_arr, axis=1)
    return int(np.argmin(distances))

def run_kmeans(input_path, centroids_path, output_path, max_iterations=15, tolerance=1e-4, use_hdfs=True):
    """
    Chạy thuật toán K-means clustering với PySpark trên HDFS
    
    Args:
        input_path: Đường dẫn HDFS đến dữ liệu đầu vào (CSV không có header)
        centroids_path: Đường dẫn HDFS đến tâm cụm ban đầu
        output_path: Đường dẫn HDFS để lưu tâm cụm cuối cùng
        max_iterations: Số lần lặp tối đa
        tolerance: Ngưỡng hội tụ
        use_hdfs: Có sử dụng HDFS hay không (mặc định True)
    """
    
    # Khởi tạo Spark với chế độ YARN/Cluster
    spark = SparkSession.builder \
        .appName("K-means Clustering - HDFS") \
        .config("spark.driver.memory", "4g") \
        .config("spark.executor.memory", "4g") \
        .config("spark.executor.instances", "4") \
        .config("spark.executor.cores", "4") \
        .config("spark.sql.shuffle.partitions", "200") \
        .config("spark.default.parallelism", "200") \
        .config("spark.hadoop.fs.defaultFS", "hdfs://localhost:9000") \
        .getOrCreate()
    
    sc = spark.sparkContext
    sc.setLogLevel("WARN")
    
    print(f"=== PYSPARK K-MEANS CLUSTERING ===")
    print(f"Đầu vào: {input_path}")
    print(f"Tâm cụm: {centroids_path}")
    print(f"Số lần lặp tối đa: {max_iterations}")
    print()
    
    # Đọc dữ liệu từ HDFS
    print("Đang đọc dữ liệu từ HDFS...")
    data_rdd = sc.textFile(input_path) \
        .map(parse_point) \
        .cache()
    
    data_count = data_rdd.count()
    print(f"Đã load {data_count:,} điểm từ {input_path}")
    
    # Đọc tâm cụm ban đầu từ HDFS
    print(f"Đang đọc tâm cụm từ {centroids_path}")
    centroids_lines = sc.textFile(centroids_path).collect()
    centroids = np.array([[float(x) for x in line.split(',')] for line in centroids_lines])
    k = len(centroids)
    print(f"Đã khởi tạo {k} tâm cụm")
    print()
    
    # Vòng lặp K-means
    for iteration in range(1, max_iterations + 1):
        print(f"=== Lần lặp {iteration}/{max_iterations} ===")
        
        # Phát sóng tâm cụm đến tất cả worker nodes
        centroids_bc = sc.broadcast(centroids)
        
        # Gán điểm vào cụm và tính toán tâm cụm mới
        # Map: (cluster_id, (point, 1))
        cluster_points = data_rdd.map(
            lambda point: (closest_centroid(point, centroids_bc), (point, 1))
        )
        
        # Reduce: tổng điểm và số lượng mỗi cụm
        cluster_sums = cluster_points.reduceByKey(
            lambda a, b: (a[0] + b[0], a[1] + b[1])
        )
        
        # Tính toán tâm cụm mới
        new_centroids_dict = cluster_sums.mapValues(
            lambda x: x[0] / x[1]
        ).collectAsMap()
        
        # Cập nhật mảng tâm cụm
        new_centroids = np.array([new_centroids_dict[i] for i in range(k)])
        
        # Kiểm tra hội tụ
        centroid_shift = np.linalg.norm(new_centroids - centroids)
        print(f"Độ dịch chuyển tâm cụm: {centroid_shift:.6f}")
        
        centroids = new_centroids
        
        if centroid_shift < tolerance:
            print(f"✅ Đã hội tụ tại lần lặp {iteration}!")
            break
        
        print()
    
    # Lưu tâm cụm cuối cùng vào HDFS
    print()
    print(f"Đang lưu tâm cụm cuối cùng vào HDFS: {output_path}")
    
    # Chuyển đổi tâm cụm thành RDD và lưu vào HDFS
    centroids_lines = [','.join(map(lambda x: f'{x:.6f}', row)) for row in centroids]
    centroids_rdd = sc.parallelize(centroids_lines, 1)
    centroids_rdd.saveAsTextFile(output_path)
    
    # Tính toán phân cụm cuối cùng
    centroids_bc = sc.broadcast(centroids)
    final_assignments = data_rdd.map(
        lambda point: closest_centroid(point, centroids_bc)
    )
    
    # Đếm số điểm mỗi cụm
    cluster_counts = final_assignments.countByValue()
    print()
    print("Kích thước các cụm:")
    for cluster_id in sorted(cluster_counts.keys()):
        count = cluster_counts[cluster_id]
        percentage = (count / data_count) * 100
        print(f"  Cụm {cluster_id}: {count:,} điểm ({percentage:.2f}%)")
    
    print()
    print("✅ Hoàn thành thuật toán K-means clustering!")
    
    spark.stop()

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Cách sử dụng: spark-submit kmeans_spark.py <đường_dẫn_hdfs_input> <đường_dẫn_hdfs_centroids> <đường_dẫn_hdfs_output> [số_lần_lặp_tối_đa]")
        print("Ví dụ: spark-submit kmeans_spark.py hdfs://localhost:9000/user/spark/input.txt hdfs://localhost:9000/user/spark/centroids.txt hdfs://localhost:9000/user/spark/output 15")
        sys.exit(1)
    
    input_path = sys.argv[1]
    centroids_path = sys.argv[2]
    output_path = sys.argv[3]
    max_iterations = int(sys.argv[4]) if len(sys.argv) > 4 else 15
    
    print(f"HDFS Đầu vào: {input_path}")
    print(f"HDFS Tâm cụm: {centroids_path}")
    print(f"HDFS Đầu ra: {output_path}")
    print()
    
    run_kmeans(input_path, centroids_path, output_path, max_iterations, use_hdfs=True)
