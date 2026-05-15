# DoneLoop

DoneLoop is a local-first native iOS task and memory assistant for people who procrastinate, forget tasks, or leave important thoughts scattered across notes, calendars, and reminders.

The product promise is simple:

> Say what is on your mind. DoneLoop captures it, organizes it, schedules it if needed, and keeps following up until you make a decision.

DoneLoop is not a chatbot, not a notes app, not a calendar clone, and not a Notion replacement. The core product is a trusted capture and follow-up loop.

## Product Direction

DoneLoop captures messy voice or text input and turns it into one of these item types:

- Task
- Reminder
- Calendar Block
- Note
- Idea
- Brain Dump

Every task must eventually move through one of these decision paths:

- Done
- Snooze
- Reschedule
- Break down
- Blocked
- Delete

The app should feel calm while forcing a decision. The selected visual direction is **Calm Focus**: native iOS, warm neutral surfaces, charcoal text, sage primary actions, amber overdue states, clear hierarchy, low visual noise, and compact screens that show only what matters.

## V1 Goal

V1 is a native iPhone MVP.

The key acceptance flow:

1. Open DoneLoop on iPhone.
2. Tap voice capture.
3. Speak: "Tomorrow at 10, block one hour to apply to Airbnb."
4. See an editable transcript.
5. Get a structured interpretation preview.
6. Save the generated task and calendar block.
7. See the item on Today.
8. Sync scheduled work to Google Calendar.
9. Receive a local reminder.
10. Choose Done, Snooze, Reschedule, Break down, Blocked, or Delete.

V1 is not done until that full loop works without paid AI.

## V1 Scope

Required V1 features:

- Native SwiftUI iOS app
- Capture screen
- Text capture
- Voice capture
- Apple speech-to-text where available
- Local data storage
- Local or rule-based parser
- Structured JSON validation before saving
- AI interpretation preview
- Task, note, idea, reminder, calendar block, and brain dump creation
- Today screen with only the most important items
- Inbox for unscheduled or unclear items
- Task detail screen
- Google Calendar sync for scheduled items only
- Local notifications
- Reminder decision sheet
- Snooze and shrink behavior
- Settings screen

Out of V1:

- Managed cloud AI
- Paid AI dependency
- Full backend
- Account system
- Cross-device sync
- Web dashboard
- Mac app
- Notion as the task system
- Team or enterprise features

## Architecture

Personal V1 architecture:

```text
iPhone App
  -> Voice or Text Capture
  -> Speech-to-Text when needed
  -> Local AI or Rule-Based Parser
  -> Structured JSON Validator
  -> Local Database
  -> Google Calendar Sync for scheduled items
  -> Local Notifications
  -> Decision Loop
```

AI should not directly run the app. AI or parsing logic should only produce structured output. Deterministic app code must validate that output and then create or update local data.

Bad pattern:

```text
User speaks -> AI decides everything -> AI mutates tasks/calendar
```

Required pattern:

```text
User speaks -> Parser returns JSON -> App validates JSON -> App executes safe local actions
```

## AI Strategy

V1 must work without paid AI.

Preferred order:

1. Local/on-device model when available.
2. Rule-based parser as fallback.
3. Optional free cloud fallback only when local parsing fails.

Future AI modes:

- Local Only
- Local + Free Cloud Fallback
- Bring Your Own Key
- Managed DoneLoop Cloud AI

All future providers should go through one internal AI provider interface:

- `parseCommand(input)`
- `summarizeBrainDump(input)`
- `breakDownTask(task)`
- `suggestTopThree(tasks)`

This keeps the app from being hardcoded to one AI company.

## Core Screens

### Capture

Main entry point for voice and text capture.

Must include:

- Large voice button
- Text input
- Editable transcript
- AI/parser interpretation preview
- Save items action
- Recent captures

### Today

Shows only what matters now.

Must include:

- Top 3 tasks
- Calendar blocks
- Overdue tasks
- Pending decisions
- Quick capture

Today must not become a giant unfiltered task list.

### Inbox

Holds unscheduled or unclear content.

Must include:

- Unscheduled tasks
- Notes
- Ideas
- Brain dumps
- Needs clarification

Example: "Work on resume" should stay in Inbox until the user schedules, breaks down, blocks, or deletes it.

### Task Detail

Shows one task and the next decision.

Must include:

- Title
- Summary
- Next action
- Due date/time
- Scheduled start/end
- Calendar status
- Snooze count
- Missed count
- Status
- Done, Snooze, Reschedule, Break down, Blocked, Delete

### Settings

Must include:

- Google Calendar connection
- AI mode
- Preferred working hours
- Default task duration
- Reminder behavior
- Privacy settings

## Data Model

Initial local models should cover:

### Tasks

- `id`
- `title`
- `summary`
- `next_action`
- `status`
- `priority`
- `category`
- `due_date`
- `due_time`
- `scheduled_start`
- `scheduled_end`
- `calendar_event_id`
- `snooze_count`
- `missed_count`
- `source`
- `ai_provider_used`
- `created_at`
- `updated_at`

### Captures

- `id`
- `raw_text`
- `audio_file_path`
- `transcript`
- `ai_output_json`
- `confidence_score`
- `created_at`

### Notes

- `id`
- `title`
- `content`
- `summary`
- `category`
- `source_capture_id`
- `created_at`
- `updated_at`

### Ideas

- `id`
- `title`
- `summary`
- `suggested_next_action`
- `converted_to_task_id`
- `created_at`
- `updated_at`

### User Settings

- `id`
- `timezone`
- `preferred_work_start`
- `preferred_work_end`
- `default_task_duration`
- `ai_mode`
- `local_model_name`
- `cloud_provider`
- `google_calendar_id`
- `created_at`
- `updated_at`

## Google Calendar Rules

DoneLoop owns tasks. Google Calendar only stores scheduled time.

Sync to Google Calendar only when the user gives a specific time or scheduling intent, such as:

- "tomorrow at 10"
- "tonight at 8"
- "every Monday"
- "block one hour"
- "schedule this"
- "remind me at"

Do not sync:

- Notes
- Ideas
- Vague tasks
- Someday items
- Brain dumps

Examples:

- "I should improve my resume." creates a task in Inbox, not a calendar event.
- "Block 45 minutes tomorrow at 7 PM to improve my resume." creates a task and calendar event.

## Reminder Loop

When a reminder fires, the user must choose:

- Done
- Snooze
- Reschedule
- Break down
- Blocked
- Delete

After repeated snoozes, DoneLoop should suggest shrinking the task.

Example:

```text
Task: Apply to 5 jobs
After two snoozes: You've avoided this twice. Want me to shrink it?
Smaller task: Apply to 1 job
Next action: Open one saved job link
```

## Roadmap

### V1: Local-First iPhone MVP

Build the working loop:

```text
Capture -> Parse -> Validate -> Save -> Schedule -> Remind -> Decide
```

### V2: Review And Organization

Planned later:

- Weekly review
- Procrastination pattern detection
- Project grouping
- Notion export
- Search
- Recurring routines
- Better task shrinking
- Semantic note organization

Notion is archive/export only. It is not the main task system.

### V3: Production And Distribution

Planned later:

- AI provider selection
- Bring Your Own Key mode
- Managed cloud AI
- Pricing tiers
- Cross-device sync
- Mac app
- Web dashboard
- Gmail integration
- Google Tasks optional sync
- Apple Reminders optional sync
- Team features

## Linear Tracking

Linear project:

- [DoneLoop iOS MVP](https://linear.app/openclaw-neutron/project/doneloop-ios-mvp-cf01b2b5c55e)

Created issue range:

- `OPE-85` through `OPE-112`

Milestones:

1. Product Foundation And Calm Focus Design
2. Native iOS App Foundation
3. Capture And Speech Input
4. Local AI Parser And Safe Execution
5. Task, Inbox, And Today Workflows
6. Google Calendar Sync
7. Reminder And Decision Loop
8. V1 QA, Roadmap, And Future Backlog

Suggested implementation order:

1. `OPE-85` Define DoneLoop V1 product rules
2. `OPE-86` Convert Calm Focus mockup into V1 screen spec
3. `OPE-87` Create native iOS design system
4. `OPE-88` Create SwiftUI iOS project skeleton
5. `OPE-89` Build local data storage layer
6. `OPE-90` Build Settings screen foundation

## Development Principles

- Build native iOS first.
- Keep V1 local-first.
- Do not require paid AI.
- Do not start with a backend unless V1 proves it needs one.
- Keep AI behind a provider interface.
- Validate structured parser output before app actions.
- Keep Google Calendar as a sync target, not the task database.
- Keep Today focused.
- Keep Inbox for vague or unscheduled items.
- Make every reminder force a decision.

## First Build Step

The first code milestone is the native SwiftUI app skeleton:

- App launches on iPhone simulator.
- Tabs exist for Capture, Today, Inbox, and Settings.
- Placeholder routes exist for Task Detail and Reminder Decision Sheet.
- Calm Focus visual tokens are started.
- No backend, account system, or paid AI is required.
