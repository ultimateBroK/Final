#!/usr/bin/env python3
import sys
import numpy as np

current_cluster = None
sum_vector = None
count = 0

for line in sys.stdin:
    line = line.strip()
    try:
        cluster, point_str = line.split('\t')
    except:
        continue
    
    if current_cluster != cluster and current_cluster is not None:
        # Output new centroid
        new_centroid = sum_vector / count
        print(','.join(map(str, new_centroid)))
        sum_vector = None
        count = 0
    
    current_cluster = cluster
    point = np.array([float(x) for x in point_str.split(',')])
    
    if sum_vector is None:
        sum_vector = point
    else:
        sum_vector += point
    count += 1

# Last cluster
if count > 0:
    new_centroid = sum_vector / count
    print(','.join(map(str, new_centroid)))
