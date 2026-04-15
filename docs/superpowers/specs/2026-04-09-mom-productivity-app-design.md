# Mom Productivity App — Design Spec
**Date:** 2026-04-09  
**Platform:** iOS 26, iPhone & iPad  
**Stack:** SwiftUI, Swift 6 (strict concurrency), SwiftData, MVVM (@Observable)

---

## Problem

New moms face a perfect storm: fractured attention, exponentially more life admin, and less cognitive bandwidth than ever. Existing solutions (Notion, Reminders, complex AI setups like Claude Code) require too much setup, maintenance, and technical know-how. Most moms will never use them.

The opportunity: an iOS app that acts as a second brain — dead simple to use, invisibly intelligent, that gets smarter the more you use it.

---

## Core Philosophy

- **Zero setup.** No forms, no preference screens, no onboarding beyond granting permissions. The AI learns by observation.
- **Capture is the primary action.** Everything else follows from it.
- **Silent by default.** The AI works in the background. No back-and-forth unless the user wants it.
- **Low friction above all.** Every design decision is evaluated against: would a sleep-deprived mom with one hand free use this?

---

## Target User

A mom (new or otherwise) who:
- Is juggling work, childcare, appointments, returns, school admin, and everything in between
- Does not have the time, energy, or technical know-how to set up complex tools
- Has an iPhone and is comfortable with basic iOS apps
- Would benefit enormously from a tool that just handles the mental load

---

## Screen Structure & Navigation

### Primary Screen
One screen. No tabs. No sidebar.

**Top:** A prominent pill-shaped capture bar (Liquid Glass material). Three entry points:
- **Hold mic icon** → voice capture
- **Tap camera icon** → photo/image capture  
- **Tap bar** → text input

**Below:** A vertically scrolling feed of AI-processed items, softly grouped into three time horizons:
- **Today** — needs attention now
- **This Week** — on the radar
- **Someday** — low urgency, don't forget

The AI decides where each item lands. The mom never files anything manually.

### From the Feed
- **Tap a card** → detail view: AI-written title, suggested first step, extracted context, and a chat thread at the bottom for optional follow-up
- **Swipe to complete** → item dismissed with satisfying animation
- **Long-press** → quick actions: snooze, add context, mark urgent
- **Settings** → accessible but not prominent; API key, notification preferences, future power-user options

### Navigation Model
`NavigationStack` with a single root view. Detail views push onto the stack. Back navigation follows standard iOS conventions. No modal overload.

### HIG Compliance
- **Hierarchy:** Capture bar dominates visually; feed items are content beneath it, never competing controls
- **Harmony:** Liquid Glass materials, concentric rounded corners matching hardware, SF Symbols exclusively
- **Consistency:** Standard iOS gestures, system fonts, expected push/pop navigation behavior

---

## Capture Experience

### Voice
- Hold mic icon → `SFSpeechRecognizer` transcribes on-device in real time
- Release → transcript queued for cloud triage
- No confirmation screen required

### Photo / Image
- Tap camera icon → system camera sheet or photo picker
- `Vision` framework extracts text and generates a scene description on-device
- Description queued for cloud triage

### Text
- Tap capture bar → keyboard appears
- Type and submit

### After Capture
- Item appears immediately in feed with a subtle "processing" indicator
- No loading screen, no blocking UI
- Once triage completes, card populates silently with title, first step, and time horizon

---

## AI Pipeline

### On-Device (fast, private, offline-capable)
- **Speech-to-text:** `AVFoundation` + `SFSpeechRecognizer`
- **Image understanding:** `Vision` framework (text extraction, scene description)
- Runs immediately on capture, no network required

### Cloud (Claude API — heavy reasoning)
Receives on-device output and returns structured JSON containing:
- Extracted task title(s)
- Suggested first step (broken down to ~10 minutes of effort)
- Time horizon: `today` | `thisWeek` | `someday`
- Deadline if detected (triggers automatic notification scheduling)
- Category tag (appointment, errand, admin, personal, etc.)

### Processing Flow
1. Mom captures → on-device processing runs immediately
2. Result queued locally (persists through app close or network loss)
3. Batch processed every few minutes, or on app foreground
4. Claude responds → SwiftData models updated → feed refreshes silently
5. Detected deadlines → `UNUserNotificationCenter` schedules reminder automatically

### Conversational Follow-Up
When a mom taps a card and types or speaks in the chat thread:
- Full conversation sent to Claude with task context + `UserProfile` summary
- Response appears as a new message in the thread
- AI can update the task's first step or time horizon based on the conversation

---

## User Context & Personal Learning

### UserProfile Model
A single SwiftData record, built entirely by observation — never by asking the user to configure anything.

**What it tracks:**
- What categories of tasks dominate her life
- What time of day she tends to complete things
- What gets snoozed repeatedly (signals deprioritization or overwhelm)
- Life constraints that emerge (childcare hours, recurring appointments, etc.)
- Communication style preferences inferred from chat interactions

**How it updates:**
- The app logs completion, snooze, and chat events continuously
- Once daily, a lightweight Claude call summarizes the observation log into a compact preference string
- That string is prepended to every subsequent triage and chat API call as part of the system prompt

**Result:** The longer a mom uses the app, the more it feels like it knows her — without her ever filling out a profile.

---

## Notifications

**In scope for v1:** `UNUserNotificationCenter`  
**Future:** EventKit calendar integration

When Claude detects a deadline or time-sensitive item during triage, it returns a scheduled notification time. The app registers this with `UNUserNotificationCenter`. Notifications appear on the lock screen with the task title and suggested first step.

Notification types:
- **Deadline reminder** — "Return window closes tomorrow: Nike shoes"
- **First step nudge** — "10 minutes free? Start: book post office appointment"
- **Daily digest** (optional, opt-in) — morning summary of today's priorities

---

## Data Model

Four SwiftData models:

### `CaptureItem`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Primary key |
| `rawContent` | String | Transcript, typed text, or image description |
| `imageReference` | String? | File path for captured image |
| `capturedAt` | Date | |
| `processingStatus` | Enum | `pending`, `processing`, `complete`, `failed` |

### `Task`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `title` | String | AI-generated |
| `firstStep` | String | AI-generated, ~10 min effort |
| `timeHorizon` | Enum | `today`, `thisWeek`, `someday` |
| `deadline` | Date? | If detected by AI |
| `category` | String | AI-assigned tag |
| `isComplete` | Bool | |
| `captureItem` | `CaptureItem` | Source |
| `messages` | `[Message]` | Conversation thread |

### `Message`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `role` | Enum | `user`, `assistant` |
| `content` | String | |
| `createdAt` | Date | |
| `task` | `Task` | Parent |

### `UserProfile`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Single record |
| `observationLog` | String | Append-only running log |
| `preferenceSummary` | String | AI-generated daily, injected into prompts |
| `lastSummarizedAt` | Date | |

---

## Cost Controls

### Batching
Captures queue locally and are sent to Claude in batches (every few minutes, or on app foreground). Multiple quick captures become a single API call.

### Smart Routing
Short, unambiguous text captures (e.g. "buy milk") may be handled locally without a cloud call if confidence is high.

### Rate Limiting
- **Free tier:** 10 cloud triage calls per day
- **Paid tier:** Unlimited
- Daily cap tracked in `UserProfile`; free users see a soft "you've reached today's limit" state with an upgrade prompt

### Context Compression
Conversation history sent to Claude is summarized after 10 turns rather than sent in full, keeping token counts bounded.

### UserProfile Summarization
The observation log is summarized once daily (one API call) rather than on every interaction.

---

## Error Handling

- **Offline:** Items queue locally, process automatically when connectivity returns. Subtle "pending" badge on card. No error shown.
- **API failure:** Silent retry with exponential backoff. After repeated failure, card shows "couldn't process yet" with a manual retry tap.
- **Speech recognition failure:** Raw transcript preserved. Mom can add context by typing.
- **All error messages:** Plain English, one suggested action. No technical language.

---

## Out of Scope (v1)

- EventKit / Apple Calendar integration (planned v2)
- Apple Reminders integration
- iMessage / email parsing
- Widget / lock screen widget
- Shared family account
- Web app
- Android

---

## Success Criteria

A mom opens the app, speaks a thought, and forgets about it. Later that day, a notification reminds her of exactly the right first step. She never had to configure anything. She comes back tomorrow.
