# How to Add Location Permissions in Xcode

## Method 1: Edit Info.plist File Directly (Easiest)

This is the simplest way:

### Step 1: Find Info.plist

1. **In the left sidebar (Navigator)**, look for a file called `Info.plist`
   - It should be under the "SnowTeeth" folder
   - It has a gray document icon

2. **Click on `Info.plist`** to open it

### Step 2: Add Permission Keys

You'll see the Info.plist file open in the editor. It looks like a table with rows.

1. **Hover over any row** - you'll see a small **+** button appear on the right
2. **Click the + button** to add a new row
3. **Start typing the key name** in the "Key" column
4. Xcode will show suggestions - look for these keys and select them:

#### Add Key 1:
- **Click +** to add a new row
- **Type**: `Privacy - Location When In Use Usage Description`
  - OR type: `NSLocationWhenInUseUsageDescription` (they're the same)
- Xcode will auto-suggest it - **press Enter** to accept
- In the **Value** column, type:
  ```
  SnowTeeth needs access to your location to track your skiing and snowboarding activities in real-time.
  ```

#### Add Key 2:
- **Click +** again to add another row
- **Type**: `Privacy - Location Always and When In Use Usage Description`
  - OR type: `NSLocationAlwaysAndWhenInUseUsageDescription`
- **Press Enter** to accept the suggestion
- In the **Value** column, type:
  ```
  SnowTeeth needs continuous access to your location to track your activities even when the app is in the background.
  ```

#### Add Key 3:
- **Click +** again
- **Type**: `Privacy - Location Always Usage Description`
  - OR type: `NSLocationAlwaysUsageDescription`
- **Press Enter**
- In the **Value** column, type:
  ```
  SnowTeeth needs continuous access to your location to track your activities even when the app is in the background.
  ```

### Step 3: Save

- Press **Cmd + S** to save the file
- You're done!

---

## Method 2: Using Project Settings (Alternative)

If you prefer using the project settings interface:

### Step 1: Open Project Settings

1. **Click on the blue "SnowTeeth" icon** at the very top of the left sidebar
   - It's the first item, has a blue app icon
   - NOT the folder, the blue icon above all folders

2. **Make sure "SnowTeeth" target is selected**:
   - In the middle column, under "TARGETS", click "SnowTeeth"
   - (There might also be a "SnowTeeth" under "PROJECT" - ignore that)

### Step 2: Find the Info Tab

1. **Look at the top of the main editor area** (the big area on the right)
2. **You'll see several tabs**: General, Signing & Capabilities, Resource Tags, Info, Build Settings, etc.
3. **Click the "Info" tab**

### Step 3: Add Custom Keys

1. **You'll see sections** like "Custom iOS Target Properties"
2. **Expand "Custom iOS Target Properties"** if it's collapsed (click the triangle)
3. **Hover over any row** in this section
4. **Click the + button** that appears

5. **Add the keys** (same as Method 1):
   - Type the key name (Xcode will suggest)
   - Select the suggestion
   - Enter the value (description)

The keys to add:
- `Privacy - Location When In Use Usage Description`
- `Privacy - Location Always and When In Use Usage Description`
- `Privacy - Location Always Usage Description`

---

## Method 3: Copy and Paste (Fastest)

If neither method above works, you can directly edit the Info.plist as XML:

### Step 1: Open Info.plist as Source Code

1. **Find Info.plist** in the left sidebar
2. **Right-click on Info.plist**
3. **Select "Open As" → "Source Code"**

### Step 2: Add the XML

You'll see XML code. Find the line that says `</dict>` near the end (but before `</plist>`).

**Add these lines** RIGHT BEFORE the `</dict>` line:

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>SnowTeeth needs access to your location to track your skiing and snowboarding activities in real-time.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>SnowTeeth needs continuous access to your location to track your activities even when the app is in the background.</string>
	<key>NSLocationAlwaysUsageDescription</key>
	<string>SnowTeeth needs continuous access to your location to track your activities even when the app is in the background.</string>
	<key>UIBackgroundModes</key>
	<array>
		<string>location</string>
	</array>
```

Your Info.plist should look like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<!-- ... other existing keys ... -->

	<!-- ADD THESE LINES -->
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>SnowTeeth needs access to your location to track your skiing and snowboarding activities in real-time.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>SnowTeeth needs continuous access to your location to track your activities even when the app is in the background.</string>
	<key>NSLocationAlwaysUsageDescription</key>
	<string>SnowTeeth needs continuous access to your location to track your activities even when the app is in the background.</string>
	<key>UIBackgroundModes</key>
	<array>
		<string>location</string>
	</array>
	<!-- END OF NEW LINES -->

</dict>
</plist>
```

### Step 3: Save and Switch Back

1. **Save** the file (Cmd + S)
2. **Right-click Info.plist** again
3. **Select "Open As" → "Property List"** to go back to normal view

---

## How to Verify It Worked

After adding the keys, check:

1. **Open Info.plist** (normal view, not source code)
2. **You should see** these keys in the list:
   - `Privacy - Location When In Use Usage Description` with your text
   - `Privacy - Location Always and When In Use Usage Description` with your text
   - `Privacy - Location Always Usage Description` with your text
   - `Required background modes` (array) with item: `location`

3. **If you see them, you're done!** ✅

---

## Troubleshooting

### Can't find Info.plist in the navigator
- Try searching: Press **Cmd + Shift + O** (Open Quickly)
- Type: `Info.plist`
- Press Enter to open it

### Added keys but they disappeared
- Make sure you saved (Cmd + S)
- Make sure you edited the right Info.plist (should be under SnowTeeth folder, not SnowTeethTests)

### Still can't find the Info tab
- You might be looking at the wrong section
- Make sure you clicked the blue PROJECT icon (not folder)
- Make sure you selected the target under "TARGETS" (not "PROJECT")

### Xcode version differences
- Older Xcode: Might say "Capabilities" instead of "Signing & Capabilities"
- Newer Xcode: Info.plist might be merged into the Info tab
- When in doubt, use **Method 3** (edit as source code) - it always works!

---

## What These Keys Do

When you run the app on a device:
- iOS will show a popup asking for location permission
- The popup will display your description text
- User can choose: "Allow Once", "Allow While Using App", or "Allow Always"

For SnowTeeth to work properly (especially background tracking), users should choose "Allow Always".

---

**Need help?** Try Method 3 (XML editing) - it's the most foolproof way!
