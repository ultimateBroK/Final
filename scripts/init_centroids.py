# init_centroids.py
import numpy as np
import polars as pl
import os

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DATA_PROCESSED = os.path.join(ROOT_DIR, 'data', 'processed')

print("Sampling for centroid initialization...")
# Polars sampling
df = pl.read_csv(os.path.join(DATA_PROCESSED, 'hadoop_input.txt'), has_header=False,
                 new_columns=[f'f{i}' for i in range(9)])

# Sample 100k rows
sample = df.sample(n=min(100000, len(df)))
data = sample.to_numpy()

k = 5  # Số clusters
print(f"Initializing {k} centroids from {len(data)} samples...")

indices = np.random.choice(len(data), k, replace=False)
centroids = data[indices]

np.savetxt(os.path.join(DATA_PROCESSED, 'centroids.txt'), centroids, delimiter=',', fmt='%.6f')
print(f"✅ Saved {k} centroids to data/processed/centroids.txt")
