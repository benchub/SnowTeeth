# SnowTeeth App Icon Specifications

This document specifies the exact icons to be used across both iOS and Android platforms. All icons are sourced from [Bootstrap Icons](https://icons.getbootstrap.com/) and licensed under MIT.

---

## Stats Page Icons

### Vertical Feet Up
- **Icon**: `arrow-up-circle-fill`
- **Color**: Green `#34C759` (iOS green)
- **Background**: None (icon is filled circle)

**SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="#34C759" class="bi bi-arrow-up-circle-fill" viewBox="0 0 16 16">
  <path d="M16 8A8 8 0 1 0 0 8a8 8 0 0 0 16 0m-7.5 3.5a.5.5 0 0 1-1 0V5.707L5.354 7.854a.5.5 0 1 1-.708-.708l3-3a.5.5 0 0 1 .708 0l3 3a.5.5 0 0 1-.708.708L8.5 5.707z"/>
</svg>
```

---

### Vertical Feet Down
- **Icon**: `arrow-down-circle-fill`
- **Color**: Red `#FF3B30` (iOS red)
- **Background**: None (icon is filled circle)

**SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="#FF3B30" class="bi bi-arrow-down-circle-fill" viewBox="0 0 16 16">
  <path d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0M8.5 4.5a.5.5 0 0 0-1 0v5.793L5.354 8.146a.5.5 0 1 0-.708.708l3 3a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 10.293z"/>
</svg>
```

---

### Horizontal Distance
- **Icon**: `arrows` (horizontal bidirectional arrows)
- **Color**: White `#FFFFFF` arrows on blue `#007AFF` (iOS blue) circular background
- **Background**: Blue circle

**Base SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
  <!-- Blue circular background -->
  <circle cx="8" cy="8" r="8" fill="#007AFF"/>
  <!-- White arrows -->
  <path fill="#FFFFFF" d="M1.146 8.354a.5.5 0 0 1 0-.708l2-2a.5.5 0 1 1 .708.708L2.707 7.5h10.586l-1.147-1.146a.5.5 0 0 1 .708-.708l2 2a.5.5 0 0 1 0 .708l-2 2a.5.5 0 0 1-.708-.708L13.293 8.5H2.707l1.147 1.146a.5.5 0 0 1-.708.708z"/>
</svg>
```

---

### Downhill Runs
- **Icon**: `trending-down` (Font Awesome)
- **Color**: White `#FFFFFF` icon on orange `#FF9500` (iOS orange) square background
- **Background**: Orange square with rounded corners
- **Scale**: Icon scaled to 60% with padding to prevent edge touching

**Base SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 576 512">
  <!-- Orange square background with rounded corners -->
  <rect x="0" y="0" width="576" height="512" rx="48" fill="#FF9500"/>
  <!-- White trending down icon - scaled and centered -->
  <g transform="translate(288, 256) scale(0.6) translate(-288, -256)">
    <path fill="#FFFFFF" d="M384 352c-17.7 0-32 14.3-32 32s14.3 32 32 32l160 0c17.7 0 32-14.3 32-32l0-160c0-17.7-14.3-32-32-32s-32 14.3-32 32l0 82.7-169.4-169.4c-12.5-12.5-32.8-12.5-45.3 0L192 242.7 54.6 105.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3l160 160c12.5 12.5 32.8 12.5 45.3 0L320 205.3 466.7 352 384 352z"/>
  </g>
</svg>
```

---

### Uphill Ascents
- **Icon**: `trending-up` (Font Awesome)
- **Color**: White `#FFFFFF` icon on purple `#AF52DE` (iOS purple) square background
- **Background**: Purple square with rounded corners
- **Scale**: Icon scaled to 60% with padding to prevent edge touching

**Base SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 576 512">
  <!-- Purple square background with rounded corners -->
  <rect x="0" y="0" width="576" height="512" rx="48" fill="#AF52DE"/>
  <!-- White trending up icon - scaled and centered -->
  <g transform="translate(288, 256) scale(0.6) translate(-288, -256)">
    <path fill="#FFFFFF" d="M384 160c-17.7 0-32-14.3-32-32s14.3-32 32-32l160 0c17.7 0 32 14.3 32 32l0 160c0 17.7-14.3 32-32 32s-32-14.3-32-32l0-82.7-169.4 169.4c-12.5 12.5-32.8 12.5-45.3 0L192 269.3 54.6 406.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3l160-160c12.5-12.5 32.8-12.5 45.3 0L320 306.7 466.7 160 384 160z"/>
  </g>
</svg>
```

---

### Loops Completed
- **Icon**: `recycle` (Bootstrap Icons)
- **Color**: White `#FFFFFF` icon on green `#34C759` (iOS green) square background
- **Background**: Green square with rounded corners
- **Scale**: Icon scaled to 70% with padding to prevent edge touching

**Base SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
  <!-- Green square background with rounded corners -->
  <rect x="0" y="0" width="16" height="16" rx="2" fill="#34C759"/>
  <!-- White recycle icon - scaled and centered -->
  <g transform="translate(8, 8) scale(0.7) translate(-8, -8)">
    <path fill="#FFFFFF" d="M9.302 1.256a1.5 1.5 0 0 0-2.604 0l-1.704 2.98a.5.5 0 0 0 .869.497l1.703-2.981a.5.5 0 0 1 .868 0l2.54 4.444-1.256-.337a.5.5 0 1 0-.26.966l2.415.647a.5.5 0 0 0 .613-.353l.647-2.415a.5.5 0 1 0-.966-.259l-.333 1.242zM2.973 7.773l-1.255.337a.5.5 0 1 1-.26-.966l2.416-.647a.5.5 0 0 1 .612.353l.647 2.415a.5.5 0 0 1-.966.259l-.333-1.242-2.545 4.454a.5.5 0 0 0 .434.748H5a.5.5 0 0 1 0 1H1.723A1.5 1.5 0 0 1 .421 12.24zm10.89 1.463a.5.5 0 1 0-.868.496l1.716 3.004a.5.5 0 0 1-.434.748h-5.57l.647-.646a.5.5 0 1 0-.708-.707l-1.5 1.5a.5.5 0 0 0 0 .707l1.5 1.5a.5.5 0 1 0 .708-.707l-.647-.647h5.57a1.5 1.5 0 0 0 1.302-2.244z"/>
  </g>
</svg>
```

---

## Main Page Button Icons

### Configuration
- **Icon**: `gear-wide-connected`
- **Color**: Same as button label color
- **Background**: None

**SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-gear-wide-connected" viewBox="0 0 16 16">
  <path d="M7.068.727c.243-.97 1.62-.97 1.864 0l.071.286a.96.96 0 0 0 1.622.434l.205-.211c.695-.719 1.888-.03 1.613.931l-.08.284a.96.96 0 0 0 1.187 1.187l.283-.081c.96-.275 1.65.918.931 1.613l-.211.205a.96.96 0 0 0 .434 1.622l.286.071c.97.243.97 1.62 0 1.864l-.286.071a.96.96 0 0 0-.434 1.622l.211.205c.719.695.03 1.888-.931 1.613l-.284-.08a.96.96 0 0 0-1.187 1.187l.081.283c.275.96-.918 1.65-1.613.931l-.205-.211a.96.96 0 0 0-1.622.434l-.071.286c-.243.97-1.62.97-1.864 0l-.071-.286a.96.96 0 0 0-1.622-.434l-.205.211c-.695.719-1.888.03-1.613-.931l.08-.284a.96.96 0 0 0-1.186-1.187l-.284.081c-.96.275-1.65-.918-.931-1.613l.211-.205a.96.96 0 0 0-.434-1.622l-.286-.071c-.97-.243-.97-1.62 0-1.864l.286-.071a.96.96 0 0 0 .434-1.622l-.211-.205c-.719-.695-.03-1.888.931-1.613l.284.08a.96.96 0 0 0 1.187-1.186l-.081-.284c-.275-.96.918-1.65 1.613-.931l.205.211a.96.96 0 0 0 1.622-.434zM12.973 8.5H8.25l-2.834 3.779A4.998 4.998 0 0 0 12.973 8.5m0-1a4.998 4.998 0 0 0-7.557-3.779l2.834 3.78zM5.048 3.967l-.087.065zm-.431.355A4.98 4.98 0 0 0 3.002 8c0 1.455.622 2.765 1.615 3.678L7.375 8zm.344 7.646.087.065z"/>
</svg>
```

---

### Visualization
- **Icon**: `emoji-heart-eyes`
- **Color**: Same as button label color
- **Background**: None

**SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-emoji-heart-eyes" viewBox="0 0 16 16">
  <path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14m0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16"/>
  <path d="M11.315 10.014a.5.5 0 0 1 .548.736A4.5 4.5 0 0 1 7.965 13a4.5 4.5 0 0 1-3.898-2.25.5.5 0 0 1 .548-.736h.005l.017.005.067.015.252.055c.215.046.515.108.857.169.693.124 1.522.242 2.152.242s1.46-.118 2.152-.242a27 27 0 0 0 1.109-.224l.067-.015.017-.004.005-.002zM4.756 4.566c.763-1.424 4.02-.12.952 3.434-4.496-1.596-2.35-4.298-.952-3.434m6.488 0c1.398-.864 3.544 1.838-.952 3.434-3.067-3.554.19-4.858.952-3.434"/>
</svg>
```

---

### Stats
- **Icon**: `bar-chart`
- **Color**: Same as button label color
- **Background**: None

**SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-bar-chart" viewBox="0 0 16 16">
  <path d="M4 11H2v3h2zm5-4H7v7h2zm5-5v12h-2V2zm-2-1a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1zM6 7a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1zm-5 4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1z"/>
</svg>
```

---

### Start Tracking
- **Icon**: `play-circle`
- **Color**: Same as button label color (typically white on green background)
- **Background**: Green button `#34C759`

**SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-play-circle" viewBox="0 0 16 16">
  <path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14m0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16"/>
  <path d="M6.271 5.055a.5.5 0 0 1 .52.038l3.5 2.5a.5.5 0 0 1 0 .814l-3.5 2.5A.5.5 0 0 1 6 10.5v-5a.5.5 0 0 1 .271-.445"/>
</svg>
```

---

### Stop Tracking
- **Icon**: `stop-circle`
- **Color**: Same as button label color (typically white on red background)
- **Background**: Red button `#FF3B30`

**SVG Code**:
```xml
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-stop-circle" viewBox="0 0 16 16">
  <path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14m0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16"/>
  <path d="M5 6.5A1.5 1.5 0 0 1 6.5 5h3A1.5 1.5 0 0 1 11 6.5v3A1.5 1.5 0 0 1 9.5 11h-3A1.5 1.5 0 0 1 5 9.5z"/>
</svg>
```

---

## Color Palette Reference

### iOS Standard Colors
- **Green**: `#34C759`
- **Red**: `#FF3B30`
- **Blue**: `#007AFF`
- **Orange**: `#FF9500`
- **Purple**: `#AF52DE`
- **White**: `#FFFFFF`

---

## Implementation Notes

### iOS (SwiftUI)
- Use SF Symbols equivalents when available, or convert SVG to PDF assets
- Import SVG as image assets in Xcode asset catalog
- For stats icons with backgrounds, create layered assets with shape + icon

### Android
- Convert SVG to Vector Drawable XML format
- Place in `res/drawable/` directory
- For icons with backgrounds, create layered vector drawables:
  ```xml
  <vector>
    <path /> <!-- Background shape -->
    <path /> <!-- Icon content -->
  </vector>
  ```
- Use `android:tint` for dynamic coloring on main page buttons

---

## License

All icons are from [Bootstrap Icons](https://icons.getbootstrap.com/) and are licensed under MIT.
