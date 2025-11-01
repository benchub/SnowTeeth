#!/usr/bin/env python3
"""
Analyze velocity data from GPX file to understand smoothing requirements
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
print(f"\nCalculating velocities...\n")

velocities = []
for i in range(1, len(points)):
    prev_lat, prev_lon, prev_ele, prev_time = points[i-1]
    curr_lat, curr_lon, curr_ele, curr_time = points[i]

    # Calculate distance and time
    dist_meters = haversine_distance(prev_lat, prev_lon, curr_lat, curr_lon)
    time_seconds = (curr_time - prev_time).total_seconds()

    if time_seconds > 0:
        velocity_mps = dist_meters / time_seconds
        velocity_mph = velocity_mps * 2.23694
        velocities.append((i, velocity_mph, time_seconds, dist_meters))

# Find velocity spikes and rapid changes
print("Point#  Velocity(mph)  TimeDelta(s)  Distance(m)  Notes")
print("="*70)

prev_vel = 0
for i, vel, time_delta, dist in velocities:
    vel_change = abs(vel - prev_vel)
    notes = []

    if vel > 20:
        notes.append("HIGH_SPEED")
    if vel_change > 5 and i > 5:  # Ignore first few points
        notes.append(f"RAPID_CHANGE(+{vel_change:.1f})")
    if vel > 1.0 and time_delta > 10:
        notes.append("LONG_INTERVAL")
    if vel < 0.5:
        notes.append("STOPPED")

    if notes or (i % 20 == 0):  # Print interesting points or every 20th point
        print(f"{i:6d}  {vel:8.2f}       {time_delta:6.1f}     {dist:8.2f}    {' '.join(notes)}")

    prev_vel = vel

# Statistics
avg_vel = sum(v for _, v, _, _ in velocities) / len(velocities)
max_vel = max(v for _, v, _, _ in velocities)
stopped_count = sum(1 for _, v, _, _ in velocities if v < 0.5)

print("\n" + "="*70)
print(f"\nStatistics:")
print(f"  Average velocity: {avg_vel:.2f} mph")
print(f"  Maximum velocity: {max_vel:.2f} mph")
print(f"  Stopped points: {stopped_count} / {len(velocities)} ({100*stopped_count/len(velocities):.1f}%)")
print(f"  Moving points: {len(velocities) - stopped_count}")

# Analyze velocity changes
changes = []
for i in range(1, len(velocities)):
    prev_vel = velocities[i-1][1]
    curr_vel = velocities[i][1]
    change = abs(curr_vel - prev_vel)
    if prev_vel > 1.0 or curr_vel > 1.0:  # Only count when actually moving
        changes.append(change)

if changes:
    avg_change = sum(changes) / len(changes)
    max_change = max(changes)
    print(f"\nVelocity changes (when moving):")
    print(f"  Average change: {avg_change:.2f} mph/reading")
    print(f"  Maximum change: {max_change:.2f} mph/reading")
