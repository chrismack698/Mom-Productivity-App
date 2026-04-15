# Testing & Phone Simulation Guide

Step-by-step instructions for building, testing, and running this app on your iPhone (simulator and physical device).

---

## Prerequisites

Before you begin, make sure you have the following installed on your Mac:

1. **Xcode 26+** — Download from the [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835) or [Apple Developer](https://developer.apple.com/xcode/)
2. **An Apple ID** — Free tier works for simulator testing; a paid Apple Developer account ($99/year) is needed for physical device deployment
3. **Command Line Tools** — Install via:
   ```bash
   xcode-select --install
   ```
4. **iOS 26 Simulator Runtime** — Installed through Xcode (see Step 2 below)

---

## Step 1: Create the Xcode Project

This repo contains the Swift source files but no `.xcodeproj` file yet. You need to create one:

1. Open **Xcode**
2. Select **File → New → Project**
3. Choose **iOS → App** and click **Next**
4. Configure the project:
   - **Product Name:** `MyApp`
   - **Team:** Select your Apple ID / team
   - **Organization Identifier:** e.g. `com.yourname` (this creates the bundle ID `com.yourname.MyApp`)
   - **Interface:** SwiftUI
   - **Storage:** SwiftData
   - **Language:** Swift
   - **Testing System:** Swift Testing
5. Save the project **inside this repo's root directory** (the folder containing `MyApp/`, `CLAUDEmdTests/`, etc.)
6. Xcode will generate starter files — **delete the auto-generated `ContentView.swift`, `MyAppApp.swift`, and `Item.swift`** from the project (they conflict with the ones already in `MyApp/`)
7. **Add existing files to the project:**
   - Right-click the `MyApp` group in the Project Navigator → **Add Files to "MyApp"...**
   - Select all files/folders under `MyApp/` (Capture, Detail, Feed, Models, Services, Settings, and root-level .swift files)
   - Make sure "Copy items if needed" is **unchecked** (files are already in place)
   - Make sure "Add to targets: MyApp" is **checked**
8. **Add the test files:**
   - Right-click the test target group → **Add Files to "MyApp"...**
   - Select all files in `CLAUDEmdTests/`
   - Add to targets: the test target (e.g. `MyAppTests`)
9. **Configure Info.plist:**
   - In the project settings, under **MyApp target → Info**, set the "Custom iOS Target Properties" or point to `MyApp/Info.plist`
   - This ensures microphone, speech recognition, and photo library permission strings are included

---

## Step 2: Install the iOS Simulator

1. Open **Xcode → Settings → Platforms** (or `Xcode → Preferences → Components` in older versions)
2. Click the **+** button and download **iOS 26** simulator runtime if not already installed
3. This download is ~5-7 GB, so it may take a while

---

## Step 3: Build and Run on the Simulator

1. In Xcode, select a simulator device from the toolbar dropdown — e.g. **iPhone 16 Pro**
2. Press **⌘R** (or click the **Play** button) to build and run
3. The iOS Simulator will launch and the app will install and open automatically
4. You should see the main feed view with the capture bar at the bottom

### Troubleshooting Build Errors

- **"No such module" errors:** Make sure all `.swift` files are added to the correct target (MyApp or the test target)
- **Swift 6 concurrency errors:** This project uses strict concurrency — make sure Build Settings → Swift Language Version is set to **Swift 6** and Strict Concurrency Checking is **Complete**
- **SwiftData schema errors:** Clean the build folder with **⌘⇧K** and rebuild

---

## Step 4: Run the Tests

This project uses the **Swift Testing** framework (not XCTest). Tests are in the `CLAUDEmdTests/` directory.

### From Xcode:
1. Press **⌘U** to run all tests
2. Or open the Test Navigator (⌘6) and click the play button next to individual tests

### What the tests cover:
| Test File | What It Tests |
|---|---|
| `ModelTests.swift` | SwiftData model creation and defaults |
| `ClaudeServiceTests.swift` | API service triage and chat |
| `CaptureViewModelTests.swift` | Voice/text capture flow |
| `FeedViewModelTests.swift` | Feed loading and filtering |
| `TaskDetailViewModelTests.swift` | Task detail and chat |
| `TriageBatchProcessorTests.swift` | Batch processing and routing |
| `UserProfileServiceTests.swift` | Profile observation and summarization |
| `NotificationServiceTests.swift` | Notification scheduling |

### Expected results:
- All tests should pass without an API key (the app uses `StubClaudeService` when no key is set)
- Tests use in-memory SwiftData containers — no persistent data is affected

---

## Step 5: Run on Your Physical iPhone

### Option A: Direct from Xcode (recommended)

1. **Connect your iPhone** to your Mac via USB (or set up wireless debugging — see below)
2. **Trust the computer** on your iPhone if prompted
3. In Xcode's device dropdown, select your iPhone (it will appear under "Devices")
4. **Set your Team** in the project's Signing & Capabilities:
   - Select the **MyApp** target → **Signing & Capabilities** tab
   - Check **Automatically manage signing**
   - Select your **Team** (your Apple ID)
   - Xcode will create a provisioning profile automatically
5. Press **⌘R** to build and deploy to your phone
6. **First time only:** On your iPhone, go to **Settings → General → VPN & Device Management** and trust the developer certificate

### Option B: Wireless Debugging (no cable needed after initial setup)

1. First, connect your iPhone via USB and open Xcode
2. Go to **Window → Devices and Simulators**
3. Select your iPhone and check **"Connect via network"**
4. Once the network icon appears next to your device, you can unplug the cable
5. Your iPhone will now appear in the device dropdown wirelessly

### Free vs. Paid Developer Account

| | Free Apple ID | Paid Developer ($99/yr) |
|---|---|---|
| Simulator | Yes | Yes |
| Deploy to your iPhone | Yes (7-day limit) | Yes (1 year) |
| App re-signing | Every 7 days | Every year |
| App Store distribution | No | Yes |
| TestFlight | No | Yes |

With a free account, the app expires on-device after 7 days and you'll need to re-deploy from Xcode.

---

## Step 6: Set Up the Claude API (Optional)

The app works without an API key (using stub responses), but for real AI triage and chat:

1. Get an API key from [console.anthropic.com](https://console.anthropic.com)
2. In Xcode, go to **Product → Scheme → Edit Scheme** (or **⌘<**)
3. Under **Run → Arguments → Environment Variables**, add:
   - Name: `ANTHROPIC_API_KEY`
   - Value: your API key
4. Rebuild and run — the app will now use the live Claude API for triage and chat

> **Note:** Environment variables only work when running from Xcode. For a standalone build on your phone, you'll need to modify `MyAppApp.swift` to read the key from a different source (e.g. Keychain or a settings bundle).

---

## Step 7: Testing Specific Features on Device

### Voice Capture
- Tap the **microphone button** in the capture bar
- Grant microphone and speech recognition permissions when prompted
- Speak a task like "Pick up kids from soccer at 4pm Thursday"
- The app will transcribe and triage it into an action item

### Photo Capture
- Tap the **camera button** in the capture bar
- Grant photo library permission when prompted
- Select or take a photo (e.g. a school flyer, a shopping list)

### Text Input
- Tap the **text field** in the capture bar
- Type a task and submit

### Feed View
- Action items appear grouped by time horizon (Today, This Week, Later)
- Tap a card to open the detail view

### Settings
- Access via the gear icon
- Configure notification preferences and app behavior

---

## Quick Reference

| Action | Shortcut / Command |
|---|---|
| Build & Run | ⌘R |
| Run All Tests | ⌘U |
| Clean Build Folder | ⌘⇧K |
| Open Test Navigator | ⌘6 |
| Edit Scheme (env vars) | ⌘< |
| Stop Running | ⌘. |
| Toggle Simulator Dark Mode | Simulator → Features → Toggle Appearance |
| Simulate Location | Simulator → Features → Location |
| Shake Gesture | Simulator → Device → Shake |

---

## Common Issues

**"Unable to install app — device is locked"**
→ Unlock your iPhone and try again.

**"Could not launch app — device not available"**
→ Make sure the iOS version on your phone is compatible with the deployment target (iOS 26).

**"Untrusted Developer"**
→ On your iPhone: Settings → General → VPN & Device Management → tap your developer profile → Trust.

**App crashes on launch**
→ Check the Xcode console (⌘⇧C) for error output. Common causes: missing SwiftData migration, missing permission strings in Info.plist.

**Tests fail with "No such module"**
→ Make sure the test target has the correct dependencies. In Xcode: test target → Build Phases → Dependencies should include `MyApp`.
