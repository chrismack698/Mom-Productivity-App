# Family Life Admin App — Revised Product & Implementation Plan

> Working title only. Do **not** ship under **MomBrain** or **BrainDump** without fresh naming work.

## Executive Summary

This product should **not** be built as a broad “AI productivity app for moms.”

It should be built as a **voice-first family life admin assistant** that helps overwhelmed users capture thoughts quickly, turn them into clear next actions, and surface only what matters today.

The original plan got a lot right:
- low-friction capture
- AI triage into a cleaner task feed
- lightweight reminders
- a focus on reducing dropped balls

But it was too broad for a first product. It included too many second-order features too early: photo capture, per-task chat, deep personalization, automatic calendar placement, API-key setup, and adjacent family-management features.

The revised plan narrows the wedge to one promise:

**“Say it once, and it won’t fall through the cracks.”**

---

## Product Thesis

The real problem is not generic productivity.

The real problem is **family life admin under cognitive overload**:
- remembering appointments
- tracking errands
- managing one-off admin tasks
- holding fragmented responsibilities in working memory
- losing thoughts in motion

The winning product is the one that feels:
- faster than Notes
- less rigid than a task manager
- less demanding than a family organizer
- more trustworthy than a generic AI assistant

This is a **habit product**, not an “AI product.”

Users will stay if the app consistently does three things well:
1. captures quickly
2. clarifies accurately
3. reduces overwhelm

---

## Repositioning

### What this app is
A **capture-and-clarify assistant for family life admin**.

### What this app is not
- a full family operating system
- a meal planner
- a pantry inventory app
- a smart home dashboard
- a general AI chat app
- a full auto-scheduler

### Better positioning language
Use language closer to **relief** than **optimization**.

Strong positioning directions:
- voice-first family admin assistant
- catch what your brain drops
- capture and clarify for home life
- the app for life admin that would otherwise slip

Avoid leaning too hard on:
- “productivity”
- “second brain”
- “AI for moms”

---

## Strategic Changes From the Original Plan

### Keep
- voice capture
- text capture
- AI triage into concrete action items
- Today / This Week / Later structure
- reminders
- snooze / done interactions
- account-scoped personalization

### Cut from v1
- photo capture
- OCR as a hero feature
- per-task conversational chat
- full automatic calendar placement
- pantry / closet / household inventory
- API-key setup for end users
- aggressive “personal learning over time” claims

### Reframe
- personalization becomes **bounded account memory**, not a full LLM wiki
- calendar integration becomes **optional suggestion / export later**, not auto-scheduling
- reminders remain in MVP because they complete the trust loop

---

## Core User

### Ideal first user
A mother with kids under 10 who:
- manages a high household mental load
- is often moving while thinking
- already uses broken workarounds like Notes, texts-to-self, or memory
- wants help catching and organizing life admin without setting up a system

### User state
The core emotional state is not “I want to be more productive.”

It is:
- “I cannot hold all of this in my head.”
- “I had the thought, but I’ll lose it.”
- “Please help me not drop the ball.”

That emotional truth should drive the UX.

---

## The MVP

## One-Sentence Product Definition
A voice-first app that turns messy life-admin thoughts into one clear next action and keeps today from slipping.

## MVP Promise
**Capture fast. Clarify well. Surface only what matters today.**

## MVP Features

### 1. Fast capture
The home screen should be almost entirely capture.

Support:
- tap-to-talk voice input
- fast text input
- minimal friction to submit

Target user experience:
- open app
- say or type a thought in under 5 seconds
- trust that it is stored and will be organized

### 2. AI cleanup into atomic actions
Every capture becomes:
- one or more clean action items
- each with a single concrete first step
- each with a lightweight priority bucket

Good output examples:
- “Reschedule pediatrician appointment”
- “Check return window for Ethan’s shoes”
- “Text daycare about Friday pickup”

Avoid:
- vague summaries
- long paragraphs
- over-complicated plans
- too many subtasks

### 3. A calming task feed
The feed should be intentionally small and calming.

Buckets:
- Today
- This Week
- Later

The goal is not to show a huge organized backlog.
The goal is to reduce overwhelm and give the user the next right thing.

### 4. Lightweight reminders
Include reminders in MVP.

Why:
They complete the product promise that the thought will not disappear.

Rules:
- only schedule when useful
- avoid over-notifying
- allow simple reminder defaults later
- no aggressive calendar automation in v1

### 5. Completion and snoozing
Every task must be easy to:
- mark done
- snooze to a later bucket
- dismiss or edit if the model got it wrong

---

## Anti-Features for v1

These should be actively avoided unless testing proves they are necessary.

### Per-task chat
It is demo-friendly but not core to the job-to-be-done.
It adds complexity without clearly reducing cognitive load.

### Photo-first capture
Useful later, but not the hero workflow.
Voice and quick text should dominate.

### Full auto-scheduling on the calendar
Too risky for trust.
Wrong calendar placement creates cleanup work.

### Inventory management
Interesting adjacency, weak wedge.
Do not dilute the first product.

### Deep automation branding
Do not market the product as “agentic.”
The user wants relief, not complexity.

---

## Personalization: Revised Approach

## Recommendation
Yes, include personalization.

But do **not** build a full Karpathy-style LLM wiki in v1.

Instead, build a **bounded, account-scoped memory layer** that helps the app make better prioritization and reminder decisions over time.

## What personalization should do
The memory system should help the app learn durable preferences like:
- preferred reminder timing
- whether the user likes smaller or larger task breakdowns
- which categories frequently get snoozed
- typical time constraints (for example school pickup windows)
- whether the user prefers “Today” to stay very small

## What personalization should not do
It should not try to remember everything.
It should not act like an always-growing diary.
It should not infer too much from isolated behavior.
It should not become an opaque black box.

## Why account-scoped memory is feasible
This is **not too complex** if kept bounded.

The complexity is not storage. The complexity is memory quality.

Main risks:
- drift from weak evidence
- over-confident inference
- poor summaries
- hard-to-correct preferences
- hidden logic the user cannot inspect

## Storage guidance
Storage is not a serious concern if memory is kept structured.

Use a local-first model store with optional user-account sync later.

Do **not** store long-term memory as one giant text blob if this product grows.

## Recommended memory architecture

### Tier 1: Raw behavioral signals
Examples:
- user snoozed an errand twice
- user completed school-related tasks quickly
- user ignored midday reminders
- user frequently edits AI-generated titles

### Tier 2: Candidate preferences
Examples:
- prefers evening reminders
- tends to defer errands
- prefers shorter task phrasing

These should require repeated evidence.

### Tier 3: Durable preferences
Only confirmed patterns should become long-term memory.

Examples:
- default reminder window: night before
- reminder quiet window: 2:30–4:00 PM
- max Today feed size: 3 items

### Tier 4: Short synthesized summary
Generate a compact profile used in prompts.

Example:
> Prefers a small Today list, responds better to evening reminders, and often defers errands unless a deadline is explicit.

This summary should be generated from structured memory, not from an endless diary.

## Memory design principles
- account-only
- visible to the user
- editable
- resettable
- bounded in size
- based on repeated evidence
- no cross-user learning claims

---

## Product Trust Principles

This product will win or lose on trust.

### Trust rules
1. Never create more cleanup work than value.
2. Do not over-schedule.
3. Do not over-notify.
4. Prefer suggestions over silent automation.
5. Let the user correct the system easily.
6. Keep the output concrete and boring.

Boring is good here.
Predictable is good here.

---

## UX Principles

### 1. Capture is the hero
The home screen should privilege capture over browsing.

### 2. Calm over comprehensiveness
Do not overwhelm the user with a giant list.

### 3. The system should feel lightweight
The app should feel closer to “held for me” than “managed by software.”

### 4. Edits should be easy
If AI is wrong, correction must be quick and frictionless.

### 5. The app should feel emotionally validating
The tone should feel warm, practical, and non-judgmental.

Avoid sounding clinical, patronizing, or productivity-bro-y.

---

## Revised Feature Roadmap

## Phase 1 — Proof of habit
Ship only:
- voice capture
- text capture
- AI task cleanup
- Today / This Week / Later feed
- reminders
- done / snooze / edit

Goal:
Prove users repeatedly capture thoughts and trust the output.

## Phase 2 — Smarter prioritization
Add:
- bounded account memory
- better reminder defaults
- smarter bucketing
- lightweight preference management

Goal:
Improve usefulness without changing the simplicity of the product.

## Phase 3 — Shared load reduction
Only after the core loop works, consider:
- partner handoff / delegation
- shared family tasks
- recurring routines
- optional calendar suggestions

Goal:
Move from “help me manage it” to “help me not carry it all alone.”

## Phase 4 — Optional adjacencies
Explore only if the core product is sticky:
- school / kid admin workflows
- document capture
- limited photo-based inputs
- household inventory categories

These are not part of the initial wedge.

---

## Revised Architecture

## Product Architecture
The original technical approach was solid but over-scoped for MVP.

### Keep technically
- SwiftUI
- SwiftData
- on-device speech where appropriate
- cloud LLM for triage
- local notifications

### Simplify technically
Remove from first build:
- chat thread model
- image capture session
- OCR pipeline
- full user-profile summarization loop
- settings for user-supplied API key

### MVP service layer
Recommended early services:
- `CaptureService`
- `TriageService`
- `FeedService`
- `NotificationService`
- `PersonalizationService` (very lightweight at first)

### MVP data models
Recommended core models:
- `CaptureItem`
- `ActionItem`
- `ReminderRule`
- `PreferenceSignal`
- `UserPreference`
- `MemorySummary`
- `AppSettings`

### Suggested simplified model intent

#### CaptureItem
Raw voice/text input before AI cleanup.

#### ActionItem
Clean, user-facing task.
Fields:
- title
- firstStep
- horizon
- optional due date
- category
- source capture reference
- status

#### PreferenceSignal
Single observed behavior.
Examples:
- snoozed errand
- ignored reminder
- edited title

#### UserPreference
Durable, confirmed preference.
Examples:
- reminder timing
- task granularity preference
- quiet windows
- preferred Today size

#### MemorySummary
A short, regenerated summary for prompting.

#### AppSettings
Local settings for reminders, subscription state, and user controls.

---

## Revised AI Design

## AI should do one main job
Convert messy inputs into useful actions.

That is the core intelligence.

## Prompting goals
The model should:
- extract clean tasks
- choose the right horizon
- write a practical first step
- avoid overproducing tasks
- avoid fake certainty

## Prompting constraints
The model should not:
- invent deadlines
- auto-schedule events by default
- over-break tasks into many subtasks
- generate long advice unless explicitly asked

## Personalization prompt use
The personalization layer should inject only a short profile summary and perhaps a few active preferences.

Keep it small.
The prompt should not include giant behavior logs.

---

## Monetization Guidance

Do not require users to supply their own model API key in the intended consumer product.

That creates too much friction and feels like a prosumer tool.

### Recommended monetization direction
- free tier with limited captures or limited reminders
- paid tier for unlimited capture, smarter memory, and optional family-sharing features later

### Do not monetize via complexity
The first paid value should be reliability and relief, not novelty.

---

## Naming Guidance

### Do not use without stronger validation
- MomBrain
- BrainDump

### Why not
- MomBrain can feel flippant or diminishing
- BrainDump is generic and crowded

### Better naming directions
Names should feel:
- calm
- held
- useful
- warm
- memorable

Examples of better directions:
- Held
- Carry
- Tend
- Homebrief
- Catchall
- Loadlight

These are placeholders, not final recommendations.
A real naming pass should check brand fit, app-store competition, and trademark risk.

---

## Success Metrics

Do not judge success by downloads alone.

### Core product metric
**Percent of captured thoughts that become completed actions without manual reorganization.**

### Supporting metrics
- capture-to-action conversion rate
- reminder usefulness rate
- edit rate on AI-created tasks
- snooze rate by category
- percentage of users who capture on 3+ distinct days per week
- percentage of users who complete at least one AI-created task per day used

### Key qualitative question
Does the user feel like the app reduced dropped balls this week?

That is the real test.

---

## Biggest Risks

### 1. Too broad too early
Trying to become a family OS before proving the capture loop.

### 2. AI cleanup that creates more work
If users must constantly edit bad outputs, trust will collapse.

### 3. Over-personalization
If the app acts too confidently on weak signals, it will feel creepy or brittle.

### 4. Weak emotional positioning
If the app sounds like generic productivity software, it will not stand out.

### 5. No habit loop
If capture does not become routine, nothing else matters.

---

## Final Recommendation

Build the product, but build a **smaller and sharper version** than the original plan.

### The right first version is:
- voice-first
- low-friction
- calming
- concrete
- trustworthy
- lightly personalized

### The wrong first version is:
- broad
- over-automated
- over-personalized
- feature-rich
- technically impressive but emotionally weak

The company is not built by showing that AI can organize life.
It is built by proving that the product reliably prevents important things from slipping away.

---

## Build Order Recommendation

### Week 1–2
- capture UX
- task creation pipeline
- feed UI
- done / snooze / edit actions

### Week 3–4
- reminder logic
- error handling
- basic analytics
- prompt refinement for cleaner task generation

### Week 5–6
- bounded memory signals
- first durable preferences
- memory settings / reset controls

### After validation
- partner sharing
- recurring routines
- calendar suggestions
- deeper personalization

---

## Final Product Standard

Before adding features, ask one question:

**Does this make it easier for the user to trust that a fleeting thought will become the next right action?**

If not, it probably does not belong in the early product.
