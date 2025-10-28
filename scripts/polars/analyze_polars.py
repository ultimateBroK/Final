# analyze_polars.py
import polars as pl
import numpy as np
import os
import gc

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_RAW = os.path.join(ROOT_DIR, 'data', 'raw', 'HI-Large_Trans.csv')
DATA_RESULTS = os.path.join(ROOT_DIR, 'data', 'results')

print("Loading results...")
clusters = np.loadtxt(os.path.join(DATA_RESULTS, 'clustered_results.txt'), dtype=int)

# Use lazy evaluation with scan_csv instead of read_csv
print("Loading CSV with lazy evaluation...")
df_lazy = pl.scan_csv(DATA_RAW)

# Add cluster column lazily
df_result = df_lazy.with_columns(pl.Series('cluster', clusters).alias('cluster'))

print("\n=== CLUSTER ANALYSIS ===\n")

# Overall statistics
print(f"Total transactions: {len(clusters):,}")
print(f"Number of clusters: {np.unique(clusters).size}")

# Cluster distribution
print("\n--- Cluster Sizes ---")
cluster_counts = df_result.group_by('cluster').agg(
    pl.len().alias('count')
).sort('cluster').collect()
print(cluster_counts)

# Laundering analysis
print("\n--- Laundering Rate per Cluster ---")
laundering_stats = df_result.group_by('cluster').agg([
    pl.len().alias('total'),
    pl.col('Is Laundering').sum().alias('laundering_count'),
    (pl.col('Is Laundering').sum() / pl.len() * 100).alias('laundering_rate')
]).sort('cluster').collect()

print(laundering_stats)
gc.collect()  # Free memory

# Identify high-risk clusters
high_risk = laundering_stats.filter(pl.col('laundering_rate') > 10.0)
print(f"\n⚠️  HIGH RISK CLUSTERS (>10% laundering):")
print(high_risk)

# Feature analysis per cluster
print("\n--- Feature Averages per Cluster ---")
feature_stats = df_result.group_by('cluster').agg([
    pl.col('Amount Received').mean().alias('avg_amount_received'),
    pl.col('Amount Paid').mean().alias('avg_amount_paid'),
    (pl.col('Amount Received') / pl.col('Amount Paid')).mean().alias('avg_ratio'),
]).sort('cluster').collect()
print(feature_stats)
gc.collect()  # Free memory

# Export suspicious transactions
if len(high_risk) > 0:
    high_risk_ids = high_risk['cluster'].to_list()
    print(f"\n📤 Exporting suspicious transactions from clusters: {high_risk_ids}")
    
    suspicious = df_result.filter(pl.col('cluster').is_in(high_risk_ids)).collect()
    suspicious_path = os.path.join(DATA_RESULTS, 'suspicious_transactions.csv')
    suspicious.write_csv(suspicious_path)
    print(f"   ✅ Saved {len(suspicious):,} suspicious transactions to data/results/suspicious_transactions.csv")
    del suspicious
    gc.collect()  # Free memory

print("\n✅ Analysis complete!")
