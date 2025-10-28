# explore_fast.py
import polars as pl
import os

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA_RAW = os.path.join(ROOT_DIR, 'data', 'raw', 'HI-Large_Trans.csv')

# Lazy scan - không load vào RAM
df = pl.scan_csv(DATA_RAW)

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
