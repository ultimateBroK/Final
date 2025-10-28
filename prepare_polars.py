# prepare_polars.py
import polars as pl
import numpy as np

print("Loading with Polars...")
df = pl.read_csv('HI-Large_Trans.csv')

print("Feature engineering...")
df_features = df.select([
    # Parse timestamp
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M').alias('datetime'),
    
    # Basic features
    pl.col('Amount Received').alias('amount_received'),
    pl.col('Amount Paid').alias('amount_paid'),
    
    # Derived features
    (pl.col('Amount Received') / (pl.col('Amount Paid') + 1e-6)).alias('amount_ratio'),
    
    # Time features
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M').dt.hour().alias('hour'),
    pl.col('Timestamp').str.strptime(pl.Datetime, format='%Y/%m/%d %H:%M').dt.weekday().alias('day_of_week'),
    
    # Route hash
    (pl.col('From Bank').hash() ^ pl.col('To Bank').hash()).alias('route_hash'),
    
    # Categorical
    pl.col('Receiving Currency').alias('recv_curr'),
    pl.col('Payment Currency').alias('payment_curr'),
    pl.col('Payment Format').alias('payment_format'),
])

print("Encoding categoricals...")
# Label encoding
df_features = df_features.with_columns([
    pl.col('recv_curr').cast(pl.Categorical).to_physical().alias('recv_curr_encoded'),
    pl.col('payment_curr').cast(pl.Categorical).to_physical().alias('payment_curr_encoded'),
    pl.col('payment_format').cast(pl.Categorical).to_physical().alias('payment_format_encoded'),
])

# Select numeric features
df_numeric = df_features.select([
    'amount_received',
    'amount_paid', 
    'amount_ratio',
    'hour',
    'day_of_week',
    'route_hash',
    'recv_curr_encoded',
    'payment_curr_encoded',
    'payment_format_encoded',
])

print("Normalizing...")
# Normalize (Polars style)
df_normalized = df_numeric.select([
    ((pl.col(c) - pl.col(c).mean()) / pl.col(c).std()).alias(c)
    for c in df_numeric.columns
])

print("Writing to hadoop_input.txt...")
df_normalized.write_csv('hadoop_input.txt', include_header=False)

print(f"✅ Created hadoop_input.txt with {len(df_normalized)} rows")
print(f"   Features: {df_normalized.columns}")
