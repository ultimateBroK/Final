#!/usr/bin/env python3
import sys
import numpy as np

# Load centroids
centroids = np.loadtxt('centroids.txt', delimiter=',')

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    
    try:
        point = np.array([float(x) for x in line.split(',')])
        
        # Find closest centroid
        distances = np.linalg.norm(centroids - point, axis=1)
        closest = np.argmin(distances)
        
        print(f"{closest}\t{line}")
    except:
        continue
