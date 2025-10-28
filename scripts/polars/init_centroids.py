# init_centroids.py
import numpy as np
import polars as pl
import os

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_PROCESSED = os.path.join(ROOT_DIR, 'data', 'processed')

print("Sampling for centroid initialization...")
# Polars sampling (use temp file)
temp_file = os.path.join(DATA_PROCESSED, 'hadoop_input_temp.txt')
if not os.path.exists(temp_file):
    print(f"❌ Temp file not found: {temp_file}")
    print("   Run prepare_polars.py first!")
    exit(1)

df = pl.read_csv(temp_file, has_header=False,
                 new_columns=[f'f{i}' for i in range(9)])

# Sample 100k rows
sample = df.sample(n=min(100000, len(df)))
data = sample.to_numpy()

k = 5  # Số clusters
print(f"Initializing {k} centroids from {len(data)} samples...")

indices = np.random.choice(len(data), k, replace=False)
centroids = data[indices]

# Save as temp file for HDFS upload
temp_centroids = os.path.join(DATA_PROCESSED, 'centroids_temp.txt')
np.savetxt(temp_centroids, centroids, delimiter=',', fmt='%.6f')
print(f"✅ Saved {k} centroids to temp file (will be uploaded to HDFS)")
print("⚠️  Remember: Temp files will be deleted after HDFS upload")
