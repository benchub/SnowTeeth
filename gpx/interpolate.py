#!/usr/bin/env python

"""
Reads a GPX file from a command-line argument, interpolates all track
segments to have a point every 10 seconds, and prints the resulting
GPX XML to standard output.

This version uses manual, linear time-based interpolation to avoid
library version incompatibilities.

All progress/error messages are printed to standard error.

Usage:
  python interpolate_gpx_stdout.py input_file.gpx > output_file.gpx
"""

import gpxpy
import gpxpy.gpx
import sys
from datetime import timedelta

# --- Configuration ---
TIME_INTERVAL_SECONDS = 10
# ---------------------

def manual_interpolate_segment(points, time_interval_seconds):
    """
    Manually interpolates a list of GPX points at a fixed time interval.
    Returns a new list of interpolated points.
    """
    if not points:
        return []

    interpolated_points = []
    interval = timedelta(seconds=time_interval_seconds)

    for i in range(len(points) - 1):
        p1 = points[i]
        p2 = points[i+1]

        # Add the starting point of the pair
        interpolated_points.append(p1)

        # Ensure both points have time data to interpolate between
        if p1.time is None or p2.time is None:
            sys.stderr.write(f"Warning: Skipping interpolation for a segment pair due to missing time data.\n")
            sys.stderr.write(f"p1.lat/lon {p1.latitude}/{p1.longitude}.\n")
            continue

        time_diff_seconds = (p2.time - p1.time).total_seconds()

        # If points are closer than the interval, just move to the next pair
        if time_diff_seconds <= time_interval_seconds:
            continue

        # Calculate deltas for position
        lat_diff = p2.latitude - p1.latitude
        lon_diff = p2.longitude - p1.longitude

        # Handle elevation, including if it's None
        p1_ele = p1.elevation if p1.elevation is not None else 0
        p2_ele = p2.elevation if p2.elevation is not None else 0
        ele_diff = p2_ele - p1_ele
        ele_is_none = p1.elevation is None and p2.elevation is None

        current_time = p1.time + interval
        
        # Loop and add new points until we reach the next original point
        while current_time < p2.time:
            # Calculate interpolation factor (t) as a 0.0-1.0 value
            t = (current_time - p1.time).total_seconds() / time_diff_seconds

            new_lat = p1.latitude + (lat_diff * t)
            new_lon = p1.longitude + (lon_diff * t)
            new_ele = p1_ele + (ele_diff * t)
            
            # Create the new point
            new_point = gpxpy.gpx.GPXTrackPoint(
                latitude=new_lat,
                longitude=new_lon,
                elevation=None if ele_is_none else new_ele,
                time=current_time
            )
            interpolated_points.append(new_point)
            
            current_time += interval

    # Add the very last point from the original segment
    interpolated_points.append(points[-1])
    
    return interpolated_points

def main():
    # Check if an input file was provided
    if len(sys.argv) < 2:
        sys.stderr.write("Error: No input file specified.\n")
        sys.stderr.write("Usage: python {} input_file.gpx > output_file.gpx\n".format(sys.argv[0]))
        sys.exit(1)

    input_file_name = sys.argv[1]

    try:
        sys.stderr.write(f"Loading '{input_file_name}'...\n")
        # Open and parse the original GPX file
        with open(input_file_name, 'r') as gpx_file:
            gpx = gpxpy.parse(gpx_file)

    except FileNotFoundError:
        sys.stderr.write(f"Error: File not found at '{input_file_name}'\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"Error parsing GPX file: {e}\n")
        sys.exit(1)


    # Create a new GPX object for the output
    interpolated_gpx = gpxpy.gpx.GPX()
    
    # Safely copy metadata if it exists (for compatibility with older gpxpy versions)
    if hasattr(gpx, 'metadata'):
        interpolated_gpx.metadata = gpx.metadata

    # Iterate through each track and segment in the original file
    for track in gpx.tracks:
        # Create a new track for the interpolated data
        new_track = gpxpy.gpx.GPXTrack(name=track.name, description=track.description)
        
        for i, segment in enumerate(track.segments):
            if not segment.points:
                continue # Skip empty segments
                
            # Create a new segment to hold the interpolated points
            new_segment = gpxpy.gpx.GPXTrackSegment()
            
            # Interpolate the segment points using our manual function
            try:
                interpolated_points = manual_interpolate_segment(segment.points, TIME_INTERVAL_SECONDS)
                new_segment.points.extend(interpolated_points)

            except Exception as e:
                sys.stderr.write(f"Warning: Could not interpolate segment {i} in track '{track.name}'. Segment will be copied as-is. Error: {e}\n")
                # If interpolation fails, just add the original points
                for point in segment.points:
                    new_segment.points.append(point)
            
            # Add the newly populated segment to the new track
            new_track.segments.append(new_segment)
            
        # Add the new track to the new GPX file
        interpolated_gpx.tracks.append(new_track)

    # Write the final XML to standard output
    sys.stdout.write(interpolated_gpx.to_xml())
    sys.stderr.write(f"Successfully processed '{input_file_name}' and printed to stdout.\n")

if __name__ == "__main__":
    main()

