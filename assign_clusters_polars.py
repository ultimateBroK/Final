# assign_clusters_polars.py
import polars as pl
import numpy as np

print("Loading centroids...")
try:
    centroids = np.loadtxt('final_centroids.txt', delimiter=',')
    if centroids.ndim == 1:
        centroids = centroids.reshape(-1, centroids.shape[0]) if centroids.size > 0 else centroids.reshape(0, 9)
    if centroids.size == 0:
        raise ValueError("Centroids file is empty")
except (ValueError, OSError) as e:
    print(f"❌ Error loading centroids: {e}")
    print("   Make sure the Hadoop job completed successfully and final_centroids.txt exists.")
    exit(1)

print("Loading data...")
df = pl.read_csv('hadoop_input.txt', has_header=False,
                 new_columns=[f'f{i}' for i in range(9)])

print("Computing distances and assigning clusters...")
data = df.to_numpy()

# Vectorized distance calculation (FAST)
distances = np.sqrt(((data[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2))
clusters = np.argmin(distances, axis=1)

print("Saving results...")
np.savetxt('clustered_results.txt', clusters, fmt='%d')

print(f"✅ Assigned {len(clusters)} transactions to clusters")
print(f"   Results saved to clustered_results.txt")
