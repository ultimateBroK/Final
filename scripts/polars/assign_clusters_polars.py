# assign_clusters_polars.py
import polars as pl
import numpy as np
import os
import subprocess

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_PROCESSED = os.path.join(ROOT_DIR, 'data', 'processed')
DATA_RESULTS = os.path.join(ROOT_DIR, 'data', 'results')
os.makedirs(DATA_RESULTS, exist_ok=True)


print("Loading centroids...")
try:
    centroids = np.loadtxt(os.path.join(DATA_PROCESSED, 'final_centroids.txt'), delimiter=',')
    if centroids.ndim == 1:
        centroids = centroids.reshape(1, -1)
    if centroids.size == 0:
        raise ValueError("Centroids file is empty")
    print(f"✅ Loaded {centroids.shape[0]} centroids with {centroids.shape[1]} features")
except (ValueError, OSError) as e:
    print(f"❌ Error loading centroids: {e}")
    print(f"   File path: {os.path.join(DATA_PROCESSED, 'final_centroids.txt')}")
    exit(1)

print("Loading data from HDFS ...")

# Stream from HDFS and read directly with Polars
try:
    print("Streaming from HDFS (this may take a while)...")
    # Use hdfs dfs -cat to stream the data
    process = subprocess.Popen(
        ["hdfs", "dfs", "-cat", "/user/spark/hi_large/input/hadoop_input.txt"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    
    # Read directly from the stream
    print("Reading CSV from HDFS stream...")
    stdout = process.stdout
    if stdout is None:
        raise Exception("HDFS process has no stdout stream")
    df = pl.read_csv(stdout, has_header=False, new_columns=[f'f{i}' for i in range(9)])
    
    # Wait for process to complete
    returncode = process.wait()
    if returncode != 0:
        stderr_data = process.stderr.read().decode() if process.stderr is not None else ""
        raise Exception(f"HDFS read failed with code {returncode}: {stderr_data}")
    print(f"✅ Loaded {len(df):,} records from HDFS")
except Exception as e:
    print(f"❌ Error loading data: {e}")
    print("   Make sure HDFS is running and the data file exists")
    exit(1)

# Convert to numpy and compute distances in batches
print("Converting to numpy and computing distances...")
data = df.to_numpy()
print(f"  Data shape: {data.shape}")
print(f"  Centroids shape: {centroids.shape}")

print("  Calculating distances to centroids (batch processing)...")
chunk_size = 100000
clusters = np.zeros(len(data), dtype=np.int32)
for i in range(0, len(data), chunk_size):
    end_idx = min(i + chunk_size, len(data))
    chunk = data[i:end_idx]
    distances = np.sqrt(((chunk[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2))
    clusters[i:end_idx] = np.argmin(distances, axis=1)
    if (i // chunk_size) % 10 == 0:
        print(f"    Processed {end_idx:,}/{len(data):,} records...")
print(f"    Processed {len(data):,}/{len(data):,} records")

print("Saving results...")
output_file = os.path.join(DATA_RESULTS, 'clustered_results.txt')
np.savetxt(output_file, clusters, fmt='%d')

print(f"✅ Assigned {len(clusters)} transactions to clusters")
print(f"   Results saved to {output_file}")
print(f"   Cluster distribution: {np.bincount(clusters)}")
