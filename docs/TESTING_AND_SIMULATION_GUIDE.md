# Testing & Phone Simulation Guide

How to connect this repo to your Xcode project, build, test, and run on your iPhone.

---

## Prerequisites

- **macOS** with **Xcode 26+** installed
- **An Apple ID** (free works for simulator; paid $99/yr needed for physical device)
- **Git** (comes with Xcode Command Line Tools)
- **Command Line Tools** — if not already installed:
  ```bash
  xcode-select --install
  ```

---

## Step 1: Clone the Repo

Open Terminal and clone the project to your Mac:

```bash
git clone https://github.com/chrismack698/Mom-Productivity-App.git
cd Mom-Productivity-App
git checkout master
```

Note the full path to this folder (e.g. `/Users/yourname/Mom-Productivity-App`). You'll need it in Step 2.

---

## Step 2: Connect Your Existing Xcode Project to the Repo

You already created a new Xcode project — now you need to move it into the cloned repo so Xcode and Git are looking at the same files.

### 2a. Find your Xcode project files

Your Xcode project lives wherever you saved it when you created it. It will look something like:

```
SomeFolder/
  MomBrain.xcodeproj      (or whatever you named it)
  MomBrain/
    MomBrainApp.swift      (auto-generated)
    ContentView.swift      (auto-generated)
    Item.swift             (auto-generated)
  MomBrainTests/
  MomBrainUITests/
```

### 2b. Copy ONLY the .xcodeproj into the cloned repo

You only need the `.xcodeproj` bundle — the actual source code already lives in the repo.

1. Open **Finder**
2. Navigate to your Xcode project folder
3. **Copy** (not move) the `MomBrain.xcodeproj` file (or whatever it's named) — it looks like a single file but it's actually a folder
4. **Paste** it into the root of the cloned repo (`Mom-Productivity-App/`)

Your repo should now look like this:

```
Mom-Productivity-App/
  MomBrain.xcodeproj       <-- you just added this
  MomBrain/                <-- source code from the repo
    MomBrainApp.swift
    ContentView.swift
    AppEnvironment.swift
    Capture/
    Detail/
    Feed/
    Models/
    Services/
    Settings/
    Info.plist
  CLAUDEmdTests/           <-- test files from the repo
  CLAUDE.md
  docs/
  ...
```

### 2c. Open the project from its new location

1. **Close Xcode** completely (Cmd+Q)
2. In Finder, **double-click** `Mom-Productivity-App/MomBrain.xcodeproj` to open it
3. Xcode will open the project from its new location inside the repo

---

## Step 3: Replace Xcode's Auto-Generated Files With the Repo's Source Code

Xcode created placeholder files when you made the project. You need to swap them out for the real source code from the repo.

### 3a. Delete the auto-generated files

In Xcode's **Project Navigator** (left sidebar, folder icon, or press **Cmd+1**):

1. Expand the **MomBrain** group
2. You'll see auto-generated files like `ContentView.swift`, `MomBrainApp.swift`, and `Item.swift`
3. **Select all of them** (click the first, then Shift+click the last)
4. Press **Delete**
5. When prompted, choose **"Move to Trash"** — you don't need these files anymore

### 3b. Add the repo's source files

1. **Right-click** the **MomBrain** group in the Project Navigator
2. Select **"Add Files to 'MomBrain'..."**
3. Navigate to the `Mom-Productivity-App/MomBrain/` folder
4. **Select everything** inside it:
   - `MomBrainApp.swift`
   - `ContentView.swift`
   - `AppEnvironment.swift`
   - `Info.plist`
   - `Capture/` (entire folder)
   - `Detail/` (entire folder)
   - `Feed/` (entire folder)
   - `Models/` (entire folder)
   - `Services/` (entire folder)
   - `Settings/` (entire folder)
5. In the dialog at the bottom, make sure:
   - **"Copy items if needed"** is **UNCHECKED** (critical — the files are already in place)
   - **"Create groups"** is selected (not "Create folder references")
   - **"Add to targets: MomBrain"** is **CHECKED**
6. Click **Add**

### 3c. Add the test files

1. In the Project Navigator, find the test target group (e.g. `MomBrainTests`)
2. **Right-click** it → **"Add Files to 'MomBrain'..."**
3. Navigate to `Mom-Productivity-App/CLAUDEmdTests/`
4. **Select all 8 test files** (CaptureViewModelTests.swift, ClaudeServiceTests.swift, etc.)
5. Make sure:
   - **"Copy items if needed"** is **UNCHECKED**
   - **"Add to targets"** has the **test target checked** (e.g. `MomBrainTests`)
6. Click **Add**

---

## Step 4: Configure the Project Settings

### 4a. Set the Info.plist

The app needs microphone, speech recognition, and photo library permissions declared:

1. Click the **MomBrain** project (blue icon) at the top of the Project Navigator
2. Select the **MomBrain** target
3. Go to the **Build Settings** tab
4. Search for `Info.plist`
5. Set the **Info.plist File** value to: `MomBrain/Info.plist`

### 4b. Set Swift Language Version

1. Still in Build Settings, search for `Swift Language Version`
2. Set it to **Swift 6**

### 4c. Set Deployment Target

1. Go to the **General** tab
2. Under **Minimum Deployments**, set iOS to **26.0**

### 4d. Set up Signing

1. Go to the **Signing & Capabilities** tab
2. Check **"Automatically manage signing"**
3. Select your **Team** (your Apple ID)
4. Xcode will create a provisioning profile for you

---

## Step 5: Build and Run on the Simulator

1. In the Xcode toolbar at the top, click the **device dropdown** (next to the play/stop buttons)
2. Under **iOS Simulators**, pick a device — e.g. **iPhone 16 Pro**
   - If no simulators appear, go to **Xcode → Settings → Platforms** and download the **iOS 26** runtime
3. Press **Cmd+R** (or click the **Play** button)
4. Xcode will compile the project and launch the simulator
5. The app will install and open — you should see the main feed with a capture bar at the bottom

### If the build fails:

| Error | Fix |
|---|---|
| "No such module 'MomBrain'" in test files | Make sure test files are in the **test target**, not the app target |
| Duplicate symbol / redeclaration | You still have auto-generated files — delete them (Step 3a) |
| "Cannot find type 'ModelContainer'" | Set deployment target to iOS 26 (Step 4c) |
| Any weird state | **Cmd+Shift+K** to clean, then **Cmd+R** to rebuild |

---

## Step 6: Run the Tests

1. Press **Cmd+U** to run all tests
2. Or open the **Test Navigator** (Cmd+6) and click the play button next to individual tests

All 8 test files use the **Swift Testing** framework (`@Test` and `#expect()`). They should all pass without any API key configured — the app stubs out the Claude API when no key is set.

---

## Step 7: Run on Your Physical iPhone

### 7a. Connect and trust

1. Plug your iPhone into your Mac with a USB cable
2. If your iPhone asks "Trust This Computer?" — tap **Trust** and enter your passcode
3. In Xcode's device dropdown, your iPhone will appear under **Devices** (may take a moment)

### 7b. Build and deploy

1. Select your iPhone from the device dropdown
2. Press **Cmd+R**
3. Xcode will build and install the app on your phone

### 7c. Trust the developer certificate (first time only)

The first time you run on a physical device, iOS will block the app:

1. On your iPhone, go to **Settings → General → VPN & Device Management**
2. Under "Developer App", tap your Apple ID / developer certificate
3. Tap **"Trust"**
4. Go back to the home screen and tap the app to launch it

### 7d. Wireless debugging (optional, skip the cable next time)

After the first USB connection:

1. In Xcode, go to **Window → Devices and Simulators**
2. Select your iPhone in the left sidebar
3. Check **"Connect via network"**
4. Wait for a globe icon to appear next to your device
5. You can now unplug the cable — your iPhone will appear wirelessly in the device dropdown

### Free Apple ID limitations

With a free (unpaid) Apple ID, the app you install on your phone **expires after 7 days**. After that, it won't launch and you'll need to rebuild from Xcode. A paid Apple Developer account ($99/year) extends this to 1 year and unlocks TestFlight and App Store distribution.

---

## Step 8: Set Up the Claude API (Optional)

The app works without an API key — it uses stub/mock responses. To enable real AI features:

1. Get an API key from [console.anthropic.com](https://console.anthropic.com)
2. In Xcode: **Product → Scheme → Edit Scheme** (or **Cmd+<**)
3. Select **Run** in the left sidebar
4. Go to the **Arguments** tab
5. Under **Environment Variables**, click **+** and add:
   - **Name:** `ANTHROPIC_API_KEY`
   - **Value:** your API key
6. Click **Close**, then rebuild (Cmd+R)

> **Note:** This env var only works when launching from Xcode. For a standalone on-device build, you'd need to store the key differently (e.g. in Keychain or a config file).

---

## Step 9: Connect Xcode to Git (Source Control)

Since you cloned the repo and placed the `.xcodeproj` inside it, Xcode should automatically detect Git. To verify:

1. Go to **Source Control → Repositories** (or press **Cmd+2** for the Source Control Navigator)
2. You should see the `Mom-Productivity-App` repo with branches, commits, etc.
3. If it doesn't appear, go to **Xcode → Settings → Source Control** and make sure "Enable Source Control" is checked

From here you can commit, push, pull, and switch branches directly from Xcode — or keep using Terminal, whichever you prefer.

---

## Quick Reference

| Action | Shortcut |
|---|---|
| Build & Run | Cmd+R |
| Run All Tests | Cmd+U |
| Clean Build | Cmd+Shift+K |
| Project Navigator | Cmd+1 |
| Source Control Navigator | Cmd+2 |
| Test Navigator | Cmd+6 |
| Edit Scheme (env vars) | Cmd+< |
| Stop Running | Cmd+. |
| Console Output | Cmd+Shift+C |

---

## Testing Features on Device

| Feature | How to test |
|---|---|
| **Voice Capture** | Tap the mic button, grant permissions, speak a task |
| **Photo Capture** | Tap the camera button, grant permissions, pick a photo |
| **Text Input** | Tap the text field, type a task, submit |
| **Feed** | Action items appear grouped by Today / This Week / Later |
| **Task Detail** | Tap any card in the feed to open detail + chat |
| **Settings** | Tap the gear icon to configure preferences |
