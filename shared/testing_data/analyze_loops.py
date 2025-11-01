#!/usr/bin/env python3
"""
Analyze loop patterns in the school.gpx file
"""

import xml.etree.ElementTree as ET
import math
from datetime import datetime

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in meters using Haversine formula"""
    R = 6371000  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    return R * c

def parse_iso_time(time_str):
    """Parse ISO 8601 time string"""
    return datetime.strptime(time_str, '%Y-%m-%dT%H:%M:%SZ')

# Parse GPX file
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
tree = ET.parse(os.path.join(script_dir, 'gpx/school.gpx'))
root = tree.getroot()

# Extract namespace
ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}

points = []
for trkpt in root.findall('.//gpx:trkpt', ns):
    lat = float(trkpt.get('lat'))
    lon = float(trkpt.get('lon'))
    ele = float(trkpt.find('gpx:ele', ns).text)
    time = parse_iso_time(trkpt.find('gpx:time', ns).text)
    points.append((lat, lon, ele, time))

print(f"Total points: {len(points)}")
print(f"Duration: {(points[-1][3] - points[0][3]).total_seconds() / 60:.1f} minutes")
print(f"\nStarting point: lat={points[0][0]:.6f}, lon={points[0][1]:.6f}")
print(f"Ending point:   lat={points[-1][0]:.6f}, lon={points[-1][1]:.6f}")

# Calculate distance from start to end
start_to_end_dist = haversine_distance(points[0][0], points[0][1], points[-1][0], points[-1][1])
print(f"Distance from start to end: {start_to_end_dist:.1f} meters")

# Find points where user returns close to starting point
start_lat, start_lon = points[0][0], points[0][1]
threshold = 50  # meters

print(f"\n=== Points within {threshold}m of start ===")
returns_to_start = []
for i, (lat, lon, ele, time) in enumerate(points):
    dist = haversine_distance(start_lat, start_lon, lat, lon)
    if dist < threshold and i > 10:  # Skip first few points
        time_since_start = (time - points[0][3]).total_seconds() / 60
        returns_to_start.append((i, dist, time_since_start))
        print(f"Point {i:3d}: {dist:5.1f}m from start (at {time_since_start:.1f} min)")

# Calculate total distance traveled
total_distance = 0
for i in range(1, len(points)):
    dist = haversine_distance(points[i-1][0], points[i-1][1], points[i][0], points[i][1])
    total_distance += dist

print(f"\n=== Overall Statistics ===")
print(f"Total distance traveled: {total_distance:.1f} meters ({total_distance/1609.34:.2f} miles)")
print(f"Times returned to start: {len(returns_to_start)}")

# Analyze elevation changes
max_ele = max(p[2] for p in points)
min_ele = min(p[2] for p in points)
print(f"Elevation range: {min_ele:.1f}m to {max_ele:.1f}m (change: {max_ele - min_ele:.1f}m)")

# Look for major direction changes (potential loop completions)
print(f"\n=== Analyzing path segments ===")

# Sample every 20 points to see major movements
sample_interval = 20
print("Time (min) | Lat      | Lon       | Distance from start")
print("-" * 60)
for i in range(0, len(points), sample_interval):
    lat, lon, ele, time = points[i]
    dist_from_start = haversine_distance(start_lat, start_lon, lat, lon)
    time_min = (time - points[0][3]).total_seconds() / 60
    print(f"{time_min:6.1f}     | {lat:.6f} | {lon:.6f} | {dist_from_start:6.1f}m")
