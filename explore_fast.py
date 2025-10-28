# explore_fast.py
import polars as pl

# Lazy scan - không load vào RAM
df = pl.scan_csv('HI-Large_Trans.csv')

# Xem schema
print(df.collect_schema)

# Sample 100k rows
sample = df.head(100000).collect()
print(sample)
print(sample.describe())

# Check laundering distribution
print("\nLaundering distribution:")
print(df.select(pl.col('Is Laundering').value_counts()).collect())

# Check currencies
print("\nTop currencies:")
print(df.select(pl.col('Receiving Currency').value_counts().head(10)).collect())
