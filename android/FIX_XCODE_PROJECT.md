# Fix: Recreate Xcode Project Properly

The project file isn't properly linked to the source files. Here's how to fix it:

## Option 1: Create New Project in Xcode (Recommended - 5 minutes)

### Step 1: Create New Project

1. **Open Xcode**
2. **File** → **New** → **Project** (or press `Cmd + Shift + N`)
3. Choose template:
   - Select **iOS** at the top
   - Select **App**
   - Click **Next**

### Step 2: Configure Project

Fill in these details:
- **Product Name**: `SnowTeeth`
- **Team**: Select your team (Personal Team is fine)
- **Organization Identifier**: `com.snowteeth` (or your own)
- **Interface**: **SwiftUI**
- **Language**: **Swift**
- **Storage**: None
- **Include Tests**: Check this box
- Click **Next**

### Step 3: Choose Location

- Navigate to the project root directory (where the iOS folder is located)
- **IMPORTANT**: Uncheck "Create Git repository" (you may already have one)
- Click **Create**

### Step 4: Delete Template Files

Xcode creates some default files we don't need:
1. In the left sidebar (Navigator), find these files under "SnowTeeth":
   - `ContentView.swift` (delete this - we have our own)
   - `SnowTeethApp.swift` (delete this - we have our own)
2. Right-click each → **Delete**
3. Choose **Move to Trash**

### Step 5: Add Our Source Files

Now add all our existing files:

1. **Right-click on "SnowTeeth" folder** in the left sidebar
2. Select **Add Files to "SnowTeeth"...**
3. Navigate to the `iOS/SnowTeeth/SnowTeeth/` directory within your project
4. **Select these items** (hold Cmd to select multiple):
   - `SnowTeethApp.swift`
   - `Info.plist`
   - `Models` folder
   - `Views` folder
   - `Utilities` folder
   - `Services` folder
   - `Assets.xcassets` folder (if not already there)
   - `Preview Content` folder (if not already there)
5. **Important Options** at the bottom:
   - ✅ Check: "Copy items if needed"
   - ✅ Check: "Create groups"
   - ✅ Check: "SnowTeeth" under "Add to targets"
6. Click **Add**

### Step 6: Add Test Files

1. **Right-click on "SnowTeethTests" folder** in the left sidebar
2. Select **Add Files to "SnowTeeth"...**
3. Navigate to the `iOS/SnowTeeth/SnowTeethTests/` directory within your project
4. **Select all test files**:
   - `VelocityCalculatorTests.swift`
   - `StatsCalculatorTests.swift`
   - `GpxWriterTests.swift`
5. **Options**:
   - ✅ Check: "Copy items if needed"
   - ✅ Check: "SnowTeethTests" under "Add to targets"
6. Click **Add**

### Step 7: Configure Info.plist

1. Click on the project (blue icon) at the top of the left sidebar
2. Select the **SnowTeeth** target
3. Go to **Info** tab
4. Find **Custom iOS Target Properties**
5. Add these keys (click + button):
   - Key: `NSLocationWhenInUseUsageDescription`
     - Type: String
     - Value: `SnowTeeth needs access to your location to track your skiing and snowboarding activities in real-time.`
   - Key: `NSLocationAlwaysAndWhenInUseUsageDescription`
     - Type: String
     - Value: `SnowTeeth needs continuous access to your location to track your activities even when the app is in the background.`
   - Key: `UIBackgroundModes`
     - Type: Array
     - Add item: `location` (String)

### Step 8: Configure Capabilities

1. Still in project settings, click **Signing & Capabilities** tab
2. Click **+ Capability** button
3. Add **Background Modes**
4. Check ✅ **Location updates**

### Step 9: Build and Run

1. Select a simulator from the device selector (top center-left)
2. Press **Cmd + R** to build and run
3. It should work now!

---

## Option 2: Quick Command Line Fix (Advanced)

If you're comfortable with command line, run this script:

```bash
cd <your-project-root>

# Back up current project
mv SnowTeeth.xcodeproj SnowTeeth.xcodeproj.backup

# Create proper project structure using swift
cat > Package.swift << 'EOF'
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SnowTeeth",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SnowTeeth", targets: ["SnowTeeth"])
    ],
    targets: [
        .target(
            name: "SnowTeeth",
            path: "SnowTeeth"
        ),
        .testTarget(
            name: "SnowTeethTests",
            dependencies: ["SnowTeeth"],
            path: "SnowTeethTests"
        )
    ]
)
EOF

# Generate Xcode project
swift package generate-xcodeproj
```

However, **Option 1 is strongly recommended** as it creates a proper iOS app project, not a Swift package.

---

## Verification

After recreating the project, you should see:

1. **In Navigator** (left sidebar):
   ```
   SnowTeeth (project)
   ├── SnowTeeth (folder)
   │   ├── SnowTeethApp.swift
   │   ├── Models/
   │   ├── Views/
   │   ├── Utilities/
   │   ├── Services/
   │   └── Assets.xcassets/
   └── SnowTeethTests (folder)
       ├── VelocityCalculatorTests.swift
       ├── StatsCalculatorTests.swift
       └── GpxWriterTests.swift
   ```

2. **Build should succeed** (Cmd + B)
3. **Run should work** (Cmd + R)

---

## Why Did This Happen?

The original `project.pbxproj` file I created was incomplete - it didn't include:
- References to the actual Swift source files
- Build phases to compile those files
- Proper file references and groups

Xcode project files are complex XML structures that are better created by Xcode itself than by hand.

---

## Troubleshooting

**Error: "No such module SnowTeeth"**
- Make sure all Swift files are added to the SnowTeeth target
- Check each file: Click file → Right sidebar → Target Membership → Check "SnowTeeth"

**Error: "Command SwiftCompile failed"**
- Make sure Swift version is set to 5.0 or later
- Project Settings → Build Settings → Swift Language Version

**Missing permissions**
- Make sure Info.plist location keys are added (Step 7)

Let me know if you hit any issues!
