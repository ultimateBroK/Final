# init_centroids.py
import numpy as np
import polars as pl

print("Sampling for centroid initialization...")
# Polars sampling
df = pl.read_csv('hadoop_input.txt', has_header=False, 
                 new_columns=[f'f{i}' for i in range(5)])

# Sample 100k rows
sample = df.sample(n=min(100000, len(df)))
data = sample.to_numpy()

k = 5  # Số clusters
print(f"Initializing {k} centroids from {len(data)} samples...")

indices = np.random.choice(len(data), k, replace=False)
centroids = data[indices]

np.savetxt('centroids.txt', centroids, delimiter=',', fmt='%.6f')
print(f"✅ Saved {k} centroids to centroids.txt")
