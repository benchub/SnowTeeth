#!/usr/bin/env python3
"""
Test elevation smoothing on block.gpx to verify improvements.

This script simulates the elevation filtering and smoothing algorithm
and compares the results against raw GPS data.
"""

import xml.etree.ElementTree as ET
from datetime import datetime
from typing import List, Dict, Optional


class ElevationSmoother:
    """Simulates the iOS/Android elevation smoothing algorithm with pattern-based spike detection."""

    def __init__(self, vertical_accuracy_threshold: float = 20.0,
                 alpha_min: float = 0.25, alpha_max: float = 0.75,
                 trend_window: int = 5, spike_reversal_threshold: float = 3.0):
        self.vertical_accuracy_threshold = vertical_accuracy_threshold
        self.alpha_min = alpha_min
        self.alpha_max = alpha_max
        self.trend_window = trend_window
        self.spike_reversal_threshold = spike_reversal_threshold
        self.previous_smoothed: Optional[float] = None
        self.recent_elevations: List[float] = []  # Raw elevations for pattern detection
        self.recent_accepted_elevations: List[float] = []  # Accepted elevations for trend detection

    def add_reading(self, elevation: float, vertical_accuracy: float = -1.0) -> float:
        """
        Apply pattern-based spike detection and adaptive EMA smoothing:
        1. Pattern-based spike detection
        2. Apply adaptive EMA smoothing
        """
        # Track raw elevations for pattern-based spike detection
        self.recent_elevations.append(elevation)
        if len(self.recent_elevations) > 4:
            self.recent_elevations.pop(0)

        # Stage 1: Pattern-based spike detection
        estimated_accuracy = self._estimate_accuracy_from_pattern()
        elevation_to_smooth = elevation
        was_rejected = False

        # Use provided vertical accuracy if available, otherwise use pattern-based estimate
        accuracy_to_use = vertical_accuracy if vertical_accuracy >= 0 else estimated_accuracy

        if accuracy_to_use > self.vertical_accuracy_threshold:
            # Poor accuracy - use previous smoothed value if available
            if self.previous_smoothed is not None:
                elevation_to_smooth = self.previous_smoothed
                was_rejected = True

        # Track accepted elevations for adaptive smoothing
        if not was_rejected:
            self.recent_accepted_elevations.append(elevation_to_smooth)
            if len(self.recent_accepted_elevations) > self.trend_window:
                self.recent_accepted_elevations.pop(0)

        # Stage 2: Adaptive EMA smoothing
        alpha = self._calculate_adaptive_alpha()

        if self.previous_smoothed is None:
            smoothed = elevation_to_smooth
        else:
            smoothed = alpha * elevation_to_smooth + (1 - alpha) * self.previous_smoothed

        self.previous_smoothed = smoothed
        return smoothed

    def _estimate_accuracy_from_pattern(self) -> float:
        """Estimate accuracy based on pattern analysis of recent elevations."""
        # Need at least 4 points to detect patterns
        if len(self.recent_elevations) < 4:
            return 20.0  # Conservative for first few points

        # Calculate recent changes
        changes = []
        for i in range(1, len(self.recent_elevations)):
            changes.append(self.recent_elevations[i] - self.recent_elevations[i-1])

        # Pattern 1: Detect reversal spikes (large change that reverses)
        if len(changes) >= 2:
            last_change = changes[-1]
            second_last_change = changes[-2]

            if (abs(last_change) > self.spike_reversal_threshold and
                abs(second_last_change) > self.spike_reversal_threshold):
                # Check if they reverse direction
                if ((last_change > 0 and second_last_change < 0) or
                    (last_change < 0 and second_last_change > 0)):
                    return 30.0  # GPS spike detected

        # Pattern 2: Detect oscillating noise (alternating directions)
        if len(changes) >= 3:
            signs = [1 if c > 0 else (-1 if c < 0 else 0) for c in changes]
            if signs[0] != 0 and signs[1] != 0 and signs[2] != 0:
                # Check if alternating: +, -, + or -, +, -
                if signs[0] != signs[1] and signs[1] != signs[2]:
                    return 25.0  # Oscillating noise

        # Pattern 3: Check for micro-jitter (small oscillations around same value)
        if len(self.recent_elevations) >= 5:
            mean = sum(self.recent_elevations) / len(self.recent_elevations)
            max_deviation = max(abs(e - mean) for e in self.recent_elevations)
            if max_deviation < 1.0:
                return 15.0  # Minor jitter while stationary

        # If no spike pattern detected, accept as legitimate
        return 8.0  # Good accuracy

    def _calculate_adaptive_alpha(self) -> float:
        """Calculate adaptive alpha based on trend detection."""
        # Need at least 3 readings to detect a trend
        if len(self.recent_accepted_elevations) < 3:
            return self.alpha_min

        # Calculate changes between consecutive accepted readings
        changes = []
        for i in range(1, len(self.recent_accepted_elevations)):
            changes.append(self.recent_accepted_elevations[i] - self.recent_accepted_elevations[i-1])

        # Count changes in same direction
        positive_count = sum(1 for c in changes if c > 0)
        negative_count = sum(1 for c in changes if c < 0)
        total_non_zero = positive_count + negative_count

        if total_non_zero == 0:
            return self.alpha_min

        majority_count = max(positive_count, negative_count)
        trend_strength = majority_count / total_non_zero

        # Consider magnitude: larger changes = stronger trend
        avg_magnitude = sum(abs(c) for c in changes) / len(changes)
        magnitude_boost = min(avg_magnitude / 2.0, 1.0)

        # Combine and map to alpha range
        combined_strength = (trend_strength + magnitude_boost) / 2.0
        alpha = self.alpha_min + combined_strength * (self.alpha_max - self.alpha_min)
        return max(self.alpha_min, min(self.alpha_max, alpha))

    def reset(self):
        self.previous_smoothed = None
        self.recent_elevations = []
        self.recent_accepted_elevations = []


def parse_gpx(file_path: str) -> List[Dict]:
    """Parse GPX file and extract track points."""
    tree = ET.parse(file_path)
    root = tree.getroot()

    # Define namespace
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}

    points = []
    for trkpt in root.findall('.//gpx:trkpt', ns):
        lat = float(trkpt.get('lat'))
        lon = float(trkpt.get('lon'))
        ele = float(trkpt.find('gpx:ele', ns).text)
        time_str = trkpt.find('gpx:time', ns).text

        points.append({
            'lat': lat,
            'lon': lon,
            'ele': ele,
            'time': time_str
        })

    return points


def calculate_statistics(elevations: List[float]) -> Dict[str, float]:
    """Calculate statistics for a list of elevations."""
    if not elevations:
        return {}

    mean = sum(elevations) / len(elevations)
    variance = sum((e - mean) ** 2 for e in elevations) / len(elevations)
    std_dev = variance ** 0.5
    min_ele = min(elevations)
    max_ele = max(elevations)

    return {
        'mean': mean,
        'std_dev': std_dev,
        'min': min_ele,
        'max': max_ele,
        'range': max_ele - min_ele
    }


def main():
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    gpx_file = os.path.join(script_dir, 'gpx/block.gpx')

    print("=" * 70)
    print("ELEVATION SMOOTHING TEST - block.gpx")
    print("=" * 70)
    print()

    # Parse GPX file
    points = parse_gpx(gpx_file)
    print(f"Total points: {len(points)}")
    print(f"Duration: {points[0]['time']} to {points[-1]['time']}")
    print()

    # Extract raw elevations
    raw_elevations = [p['ele'] for p in points]

    # Simulate vertical accuracy (in real data, this would come from GPS)
    # For this test, we'll assume poor accuracy when elevation changes rapidly
    def estimate_vertical_accuracy(idx: int, points: List[Dict]) -> float:
        """Estimate vertical accuracy based on elevation variance."""
        if idx < 5 or idx >= len(points) - 5:
            # Start and end might have poor accuracy
            return 20.0

        # Look at elevation change in surrounding points
        window = points[max(0, idx-5):min(len(points), idx+6)]
        elevations = [p['ele'] for p in window]
        mean = sum(elevations) / len(elevations)
        variance = sum((e - mean) ** 2 for e in elevations) / len(elevations)
        std_dev = variance ** 0.5

        # High variance suggests poor GPS quality
        if std_dev > 3:
            return 25.0  # Poor accuracy
        elif std_dev > 2:
            return 18.0  # Moderate accuracy
        else:
            return 10.0  # Good accuracy

    # Apply smoothing with pattern-based spike detection and adaptive alpha
    smoother = ElevationSmoother(
        vertical_accuracy_threshold=20.0,
        alpha_min=0.25,
        alpha_max=0.75,
        trend_window=5,
        spike_reversal_threshold=3.0
    )
    smoothed_elevations = []
    rejected_count = 0

    for idx, point in enumerate(points):
        v_acc = estimate_vertical_accuracy(idx, points)
        smoothed = smoother.add_reading(point['ele'], v_acc)
        smoothed_elevations.append(smoothed)

        if v_acc > 15.0:
            rejected_count += 1

    # Calculate statistics
    raw_stats = calculate_statistics(raw_elevations)
    smoothed_stats = calculate_statistics(smoothed_elevations)

    print("RAW ELEVATION STATISTICS:")
    print(f"  Mean:     {raw_stats['mean']:.2f}m")
    print(f"  Std Dev:  {raw_stats['std_dev']:.2f}m")
    print(f"  Min:      {raw_stats['min']:.2f}m")
    print(f"  Max:      {raw_stats['max']:.2f}m")
    print(f"  Range:    {raw_stats['range']:.2f}m")
    print()

    print("SMOOTHED ELEVATION STATISTICS:")
    print(f"  Mean:     {smoothed_stats['mean']:.2f}m")
    print(f"  Std Dev:  {smoothed_stats['std_dev']:.2f}m")
    print(f"  Min:      {smoothed_stats['min']:.2f}m")
    print(f"  Max:      {smoothed_stats['max']:.2f}m")
    print(f"  Range:    {smoothed_stats['range']:.2f}m")
    print()

    print("IMPROVEMENTS:")
    print(f"  Std Dev Reduction: {raw_stats['std_dev'] - smoothed_stats['std_dev']:.2f}m "
          f"({(1 - smoothed_stats['std_dev']/raw_stats['std_dev'])*100:.1f}% improvement)")
    print(f"  Range Reduction:   {raw_stats['range'] - smoothed_stats['range']:.2f}m "
          f"({(1 - smoothed_stats['range']/raw_stats['range'])*100:.1f}% improvement)")
    print(f"  Readings Rejected: {rejected_count}/{len(points)} "
          f"({rejected_count/len(points)*100:.1f}%)")
    print()

    # Show specific problem areas
    print("PROBLEM AREAS (first 100 points):")
    print(f"{'Index':<8} {'Time':<10} {'Raw':<8} {'Smoothed':<10} {'Change':<8} {'V.Acc':<8}")
    print("-" * 70)

    for i in range(min(100, len(points))):
        if i > 0:
            raw_change = points[i]['ele'] - points[i-1]['ele']
            smoothed_change = smoothed_elevations[i] - smoothed_elevations[i-1]
            v_acc = estimate_vertical_accuracy(i, points)

            # Show significant changes or rejections
            if abs(raw_change) > 2.0 or v_acc > 15.0:
                time = points[i]['time'].split('T')[1][:8]
                print(f"{i:<8} {time:<10} {points[i]['ele']:<8.1f} "
                      f"{smoothed_elevations[i]:<10.1f} {raw_change:<8.1f} {v_acc:<8.1f}")

    print()
    print("=" * 70)
    print("CONCLUSION:")
    print("=" * 70)

    if smoothed_stats['std_dev'] < raw_stats['std_dev']:
        print("✅ Elevation smoothing successfully reduced GPS noise")
        print(f"   Standard deviation improved by {(1-smoothed_stats['std_dev']/raw_stats['std_dev'])*100:.1f}%")
    else:
        print("❌ Elevation smoothing did not improve standard deviation")

    if smoothed_stats['range'] < raw_stats['range']:
        print("✅ Elevation smoothing reduced false elevation changes")
        print(f"   Elevation range improved by {(1-smoothed_stats['range']/raw_stats['range'])*100:.1f}%")
    else:
        print("❌ Elevation smoothing did not reduce range")

    print()


if __name__ == '__main__':
    main()
