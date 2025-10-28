#!/usr/bin/env python3
# kmeans_spark.py - K-means clustering using PySpark

import sys
import numpy as np
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf
from pyspark.sql.types import IntegerType, ArrayType, DoubleType
import os

def parse_point(line):
    """Parse CSV line to numpy array"""
    return np.array([float(x) for x in line.split(',')])

def closest_centroid(point, centroids_bc):
    """Find closest centroid index"""
    centroids = centroids_bc.value
    point_arr = np.array(point)
    distances = np.linalg.norm(centroids - point_arr, axis=1)
    return int(np.argmin(distances))

def run_kmeans(input_path, centroids_path, output_path, max_iterations=15, tolerance=1e-4, use_hdfs=True):
    """
    Run K-means clustering using PySpark with HDFS
    
    Args:
        input_path: HDFS path to input data (CSV without header)
        centroids_path: HDFS path to initial centroids
        output_path: HDFS path to save final centroids
        max_iterations: Maximum number of iterations
        tolerance: Convergence threshold
        use_hdfs: Whether to use HDFS (default True)
    """
    
    # Initialize Spark with YARN/Cluster mode
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
    
    print(f"=== PySpark K-means Clustering ===")
    print(f"Input: {input_path}")
    print(f"Centroids: {centroids_path}")
    print(f"Max iterations: {max_iterations}")
    print()
    
    # Load data from HDFS
    print("Loading data from HDFS...")
    data_rdd = sc.textFile(input_path) \
        .map(parse_point) \
        .cache()
    
    data_count = data_rdd.count()
    print(f"Loaded {data_count:,} points from {input_path}")
    
    # Load initial centroids from HDFS
    print(f"Loading centroids from {centroids_path}")
    centroids_lines = sc.textFile(centroids_path).collect()
    centroids = np.array([[float(x) for x in line.split(',')] for line in centroids_lines])
    k = len(centroids)
    print(f"Initialized {k} centroids")
    print()
    
    # K-means iterations
    for iteration in range(1, max_iterations + 1):
        print(f"=== Iteration {iteration}/{max_iterations} ===")
        
        # Broadcast centroids
        centroids_bc = sc.broadcast(centroids)
        
        # Assign points to clusters and compute new centroids
        # Map: (cluster_id, (point, 1))
        cluster_points = data_rdd.map(
            lambda point: (closest_centroid(point, centroids_bc), (point, 1))
        )
        
        # Reduce: sum points and counts per cluster
        cluster_sums = cluster_points.reduceByKey(
            lambda a, b: (a[0] + b[0], a[1] + b[1])
        )
        
        # Compute new centroids
        new_centroids_dict = cluster_sums.mapValues(
            lambda x: x[0] / x[1]
        ).collectAsMap()
        
        # Update centroids array
        new_centroids = np.array([new_centroids_dict[i] for i in range(k)])
        
        # Check convergence
        centroid_shift = np.linalg.norm(new_centroids - centroids)
        print(f"Centroid shift: {centroid_shift:.6f}")
        
        centroids = new_centroids
        
        if centroid_shift < tolerance:
            print(f"✅ Converged at iteration {iteration}!")
            break
        
        print()
    
    # Save final centroids to HDFS
    print()
    print(f"Saving final centroids to HDFS: {output_path}")
    
    # Convert centroids to RDD and save to HDFS
    centroids_lines = [','.join(map(lambda x: f'{x:.6f}', row)) for row in centroids]
    centroids_rdd = sc.parallelize(centroids_lines, 1)
    centroids_rdd.saveAsTextFile(output_path)
    
    # Compute final cluster assignments
    centroids_bc = sc.broadcast(centroids)
    final_assignments = data_rdd.map(
        lambda point: closest_centroid(point, centroids_bc)
    )
    
    # Count points per cluster
    cluster_counts = final_assignments.countByValue()
    print()
    print("Cluster sizes:")
    for cluster_id in sorted(cluster_counts.keys()):
        count = cluster_counts[cluster_id]
        percentage = (count / data_count) * 100
        print(f"  Cluster {cluster_id}: {count:,} points ({percentage:.2f}%)")
    
    print()
    print("✅ K-means clustering completed!")
    
    spark.stop()

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: spark-submit kmeans_spark.py <hdfs_input_path> <hdfs_centroids_path> <hdfs_output_path> [max_iterations]")
        print("Example: spark-submit kmeans_spark.py hdfs://localhost:9000/user/spark/input.txt hdfs://localhost:9000/user/spark/centroids.txt hdfs://localhost:9000/user/spark/output 15")
        sys.exit(1)
    
    input_path = sys.argv[1]
    centroids_path = sys.argv[2]
    output_path = sys.argv[3]
    max_iterations = int(sys.argv[4]) if len(sys.argv) > 4 else 15
    
    print(f"HDFS Input: {input_path}")
    print(f"HDFS Centroids: {centroids_path}")
    print(f"HDFS Output: {output_path}")
    print()
    
    run_kmeans(input_path, centroids_path, output_path, max_iterations, use_hdfs=True)
