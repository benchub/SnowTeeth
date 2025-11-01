# Snow Accumulation System Documentation

This directory contains comprehensive documentation for the contour-following height-map snow accumulation system implemented in SnowTeeth.

## Overview

The SnowTeeth app features a sophisticated particle system where snow accumulates on UI elements (text letters and buttons) following the exact contours of their shapes, with natural-looking probabilistic stacking and dynamic erosion.

## Documentation Structure

1. **[01-architecture.md](01-architecture.md)** - System architecture and core concepts
2. **[02-contour-following.md](02-contour-following.md)** - Contour-following height-map implementation
3. **[03-per-letter-rendering.md](03-per-letter-rendering.md)** - The per-letter rendering solution
4. **[04-probabilistic-dynamics.md](04-probabilistic-dynamics.md)** - Probabilistic stacking and random erosion
5. **[05-cross-platform.md](05-cross-platform.md)** - iOS and Android implementation details
6. **[06-debugging-guide.md](06-debugging-guide.md)** - Common issues and solutions
7. **[07-lessons-learned.md](07-lessons-learned.md)** - Key insights and debugging lessons

## Quick Start

For a quick understanding of the system:
1. Read the architecture overview in [01-architecture.md](01-architecture.md)
2. Understand the contour-following approach in [02-contour-following.md](02-contour-following.md)
3. Review the per-letter rendering solution in [03-per-letter-rendering.md](03-per-letter-rendering.md)

## Key Features

- **O(1) Collision Detection**: Height-map based collision instead of tracking individual stuck particles
- **Contour Following**: Snow follows the exact curves of letters (e.g., the arch of 'h', the curves of 'S')
- **Button Corner Exclusion**: No accumulation on rounded corners of buttons
- **Probabilistic Stacking**: Natural-looking varied heights with cubic falloff
- **Random Erosion**: Dynamic melting effect for evolving snow landscape
- **Cross-Platform Parity**: Identical behavior on iOS and Android
