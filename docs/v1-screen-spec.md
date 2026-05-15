# DoneLoop V1 Screen Spec

This document turns the selected Calm Focus mockup direction into buildable V1 screen requirements.

It should be read with `docs/product-rules.md`. Product rules define what DoneLoop is. This screen spec defines how the first native iOS screens should behave.

## Calm Focus Direction

DoneLoop should feel calm while still forcing a decision.

Use these design rules across V1:

- Native iOS patterns first.
- Warm off-white app background.
- Charcoal primary text.
- Sage primary actions.
- Amber for overdue or attention states.
- Green for completed or positive status.
- Red only for destructive actions or serious errors.
- Hairline dividers.
- Minimal shadows.
- 8px maximum card radius unless a native iOS control requires otherwise.
- Compact screens with clear hierarchy.
- No chatbot bubbles.
- No web dashboard chrome.
- No Notion-style document blocks as the main UI.
- No decorative gradient blobs or marketing hero sections.

Primary tabs:

1. Capture
2. Today
3. Inbox
4. Settings

Secondary routes:

- Task Detail
- Reminder Decision Sheet
- Capture Detail
- Interpretation Preview
- Calendar Connection Flow

## Shared UI Rules

### Navigation

Use a native bottom tab bar for the four primary tabs.

Default launch tab: Capture.

Deep links from notifications should open the Reminder Decision Sheet for the relevant task. If the task no longer exists, open Today with a short message.

### Empty States

Empty states should be short and practical.

Do not use motivational quotes. Do not explain the whole app inside empty states.

### Loading States

Use small native progress indicators and disabled actions. Do not block the whole screen unless an action is actively saving.

### Error States

Errors must say what happened and what the user can do next.

Examples:

- "Microphone access is off. Enable it in Settings to use voice capture."
- "Calendar is disconnected. The task was saved locally."
- "This interpretation needs a time before it can go on your calendar."

### Local Data Shown In UI

Screens should read from local storage first. Google Calendar and AI providers are helpers, not the source of truth.

## Screen: Capture

### Purpose

Capture is the main entry point. It lets the user quickly speak or type a messy thought and review what DoneLoop understood.

### Primary Action

Start voice capture.

### Secondary Actions

- Type a thought.
- Stop recording.
- Cancel recording.
- Edit transcript or typed input.
- Interpret input.
- Save interpreted items.
- Open recent captures.

### Required Visible Information

- Large centered microphone button.
- Recording or idle state.
- Editable transcript or text input.
- Interpretation preview after parsing.
- Recent captures list.
- Capture source: voice or text.
- Parser mode used when available: Local, Rule-based, or Cloud fallback.

### Default Layout

Top area:

- Screen title: "Capture"
- Small status line if needed: "Local first" or current AI mode.

Main area:

- Large circular mic control.
- Recording state or text input.
- Transcript editor after voice capture.

Preview area:

- Structured interpretation cards once parsing completes.
- Save Items button.

Bottom area:

- Recent captures list with compact rows.

### UI Behavior

Before capture:

- Mic button is the strongest visual element.
- Text capture field is available but secondary.
- Recent captures appear below.

During recording:

- Mic button changes to stop state.
- Show a simple waveform or activity indicator.
- Show elapsed time if available.

After recording:

- Show editable transcript.
- Enable Interpret action when transcript is not empty.

After interpretation:

- Show grouped suggested items.
- Let user edit or remove suggested items before saving.
- Disable Save Items if validation fails.

### Data Requirements

Reads:

- Recent captures.
- User settings for AI mode and privacy.

Writes:

- Capture record.
- Transcript or raw text.
- Parser output JSON.
- Confidence score or validation warnings when available.

### Empty State

No captures:

```text
Capture something before it slips.
```

Show mic and text input.

### Loading State

While interpreting:

- Disable Save Items.
- Show "Structuring..." with small progress indicator.
- Keep transcript visible.

### Error State

Examples:

- Microphone permission denied.
- Speech recognition unavailable.
- Local parser unavailable.
- Invalid interpretation.

The user must always be able to edit text manually.

## Screen: Interpretation Preview

### Purpose

Show what DoneLoop thinks the user meant before anything is saved.

### Primary Action

Save valid interpreted items.

### Secondary Actions

- Edit item.
- Remove item.
- Retry interpretation.
- Save vague item to Inbox.
- Cancel.

### Required Visible Information

For each interpreted item:

- Type chip: Task, Reminder, Calendar, Note, Idea, or Brain Dump.
- Title.
- Summary when useful.
- Next action when available.
- Schedule or "No time set".
- Calendar status: Required, Not needed, or Needs time.
- Warning or confidence note when needed.

### UI Behavior

Show one compact card or row per item.

Calendar-required items should be visually clear but not alarming.

If an item is vague, show a clarification prompt:

```text
When do you want to work on this?
```

### Data Requirements

Reads:

- Parser output.
- Validation result.
- Source capture.

Writes only after save:

- Tasks.
- Notes.
- Ideas.
- Brain dumps.
- Calendar sync pending state.

### Empty State

If parser returns nothing useful:

```text
I need a little more detail before saving this.
```

Allow user to edit input.

### Loading State

Same as Capture interpretation loading state.

### Error State

Invalid output:

```text
This interpretation has a problem. Edit it or try again.
```

Save must be disabled until valid.

## Screen: Today

### Purpose

Today shows only what matters now.

It is not a full task list.

### Primary Action

Open or act on the most important task.

### Secondary Actions

- Quick capture.
- Open calendar block.
- Open overdue item.
- Open pending decision.
- Navigate to Inbox.

### Required Visible Information

- Top 3 tasks.
- Calendar blocks for today.
- Overdue tasks.
- Pending decisions.
- Quick capture button.

### Default Layout

Top:

- Date.
- Quick capture button.

Main sections:

1. Top 3
2. Calendar Blocks
3. Needs Decision
4. Overdue

### UI Behavior

Top 3 should be the most prominent section. If deterministic sorting is used before AI suggestions exist, rank by schedule, overdue status, priority, and pending decision state.

Calendar blocks should be compact timeline rows.

Overdue items use amber attention state, not red.

Do not show every task. Link to Inbox or future list views instead.

### Data Requirements

Reads:

- Local tasks.
- Scheduled start and end.
- Status.
- Priority.
- Snooze count.
- Missed count.
- Calendar sync status.

Writes:

- Quick status updates when supported.
- Navigation state.

### Empty State

No tasks today:

```text
Nothing scheduled. Capture something or clear your Inbox.
```

### Loading State

Use skeleton rows or a small progress indicator only if local storage is loading.

### Error State

If local data cannot load:

```text
Today could not load. Your local data was not changed.
```

## Screen: Inbox

### Purpose

Inbox holds unscheduled or unclear content until the user decides what to do with it.

### Primary Action

Clarify or schedule an Inbox item.

### Secondary Actions

- Break down.
- Mark blocked.
- Delete.
- Convert idea to task.
- Open note or brain dump.

### Required Visible Information

Grouped sections:

- Unscheduled Tasks
- Notes
- Ideas
- Brain Dumps
- Needs Clarification

Each row should show:

- Title.
- Short summary.
- Type.
- Source or capture date.
- Suggested next action when available.

### UI Behavior

For vague tasks, show the key prompt:

```text
When do you want to work on this?
```

Inbox should feel like triage, not a document archive.

### Data Requirements

Reads:

- Local unscheduled tasks.
- Notes.
- Ideas.
- Brain dumps.
- Validation outputs needing clarification.

Writes:

- Schedule decisions.
- Delete decisions.
- Blocked status.
- Converted idea links.

### Empty State

```text
Inbox is clear.
```

### Loading State

Use grouped skeleton rows only if local data is loading.

### Error State

If an item cannot be updated:

```text
That item could not be updated. Try again.
```

## Screen: Task Detail

### Purpose

Task Detail explains one task and makes the next decision obvious.

### Primary Action

Act on the task using one of the six decision actions.

### Secondary Actions

- Edit title.
- Edit next action.
- Change schedule.
- View source capture.
- Retry calendar sync.

### Required Visible Information

- Title.
- Summary.
- Next action.
- Due date and time.
- Scheduled start and end.
- Calendar status.
- Snooze count.
- Missed count.
- Status.
- Priority.
- Category.
- Source capture link when available.

### Decision Actions

Show all six:

- Done
- Snooze
- Reschedule
- Break down
- Blocked
- Delete

Delete must be visually separated and require confirmation.

### UI Behavior

Next action should be more prominent than summary.

Calendar status labels:

- Not scheduled
- Calendar pending
- Synced
- Sync failed
- Calendar disconnected

### Data Requirements

Reads:

- Local task.
- Source capture.
- Calendar event ID.
- Notification status.

Writes:

- Status.
- Schedule.
- Snooze count.
- Missed count.
- Blocked reason when available.

### Empty State

If task is missing:

```text
This task no longer exists.
```

Return to Today.

### Loading State

Show title placeholder and disabled actions.

### Error State

Calendar sync failure:

```text
Saved locally. Calendar sync failed.
```

Offer Retry if calendar is connected.

## Screen: Reminder Decision Sheet

### Purpose

Force a decision when a reminder fires.

### Primary Action

Choose one decision action.

### Secondary Actions

- Open full Task Detail.
- Dismiss temporarily if allowed by iOS, while recording missed count where possible.

### Required Visible Information

- Task title.
- Next action.
- Scheduled time or due time.
- Snooze count if greater than zero.
- Six decision actions.
- Shrink suggestion after repeated snoozes.

### UI Behavior

Use a native bottom sheet when opened inside the app.

When opened from notification, route directly to this sheet or an equivalent full-screen decision state.

After two snoozes, show:

```text
You've avoided this twice. Want me to shrink it?
```

The tone should be direct, not judgmental.

### Data Requirements

Reads:

- Local task.
- Notification payload.
- Snooze count.
- Missed count.

Writes:

- Task status.
- Snooze count.
- New reminder time.
- Blocked status.
- Smaller task when break down or shrink is accepted.

### Empty State

If the notification points to a deleted or completed task:

```text
This task is already handled.
```

### Loading State

Show task title placeholder and disabled decision buttons.

### Error State

If an action fails:

```text
That decision was not saved. Try again.
```

## Screen: Settings

### Purpose

Let the user control DoneLoop's local-first behavior.

### Primary Action

Update app settings.

### Secondary Actions

- Connect Google Calendar.
- Change AI mode.
- Set working hours.
- Set default task duration.
- Change reminder behavior.
- Review privacy settings.

### Required Visible Information

Sections:

1. Google Calendar
2. AI Mode
3. Working Hours
4. Default Task Duration
5. Reminder Behavior
6. Privacy
7. App Info

AI Mode options:

- Local Only
- Local + Free Cloud Fallback
- Bring Your Own Key

Bring Your Own Key may be shown as future or unavailable until implemented.

### UI Behavior

Use native list rows, segmented controls, toggles, and time pickers.

Privacy text should be plain:

```text
Local captures stay on this device unless you enable a cloud fallback.
```

### Data Requirements

Reads and writes:

- Timezone.
- Preferred work start.
- Preferred work end.
- Default task duration.
- AI mode.
- Local model name.
- Cloud provider.
- Google calendar ID.
- Reminder preferences.

### Empty State

Settings should always show defaults, even on first launch.

### Loading State

Use small row-level loading indicators when checking Calendar connection.

### Error State

Calendar disconnected:

```text
Calendar is disconnected. Scheduled tasks will stay local.
```

Cloud fallback unavailable:

```text
Cloud fallback is unavailable. DoneLoop will use local parsing.
```

## Screen: Google Calendar Connection

### Purpose

Let the user connect, disconnect, or repair Google Calendar sync.

### Primary Action

Connect Google Calendar.

### Secondary Actions

- Pick calendar.
- Disconnect.
- Retry connection.

### Required Visible Information

- Connected or disconnected state.
- Account name when available.
- Selected calendar name when available.
- Permission problem if access was denied.

### UI Behavior

Calendar connection is launched from Settings.

If connection fails, the user should still be able to save tasks locally.

### Data Requirements

Reads and writes:

- Calendar connection status.
- Google calendar ID.
- Secure token state.

### Empty State

Disconnected:

```text
Connect Google Calendar to sync scheduled work blocks.
```

### Loading State

Show "Connecting..." while auth is in progress.

### Error State

Permission denied:

```text
Calendar permission was not granted. Scheduled work will stay local.
```

## Basic Global States

### No Captures

Capture still shows mic and text input. Recent captures shows a short empty state.

### No Tasks Today

Today points to Capture and Inbox.

### Disconnected Google Calendar

Scheduled tasks save locally and show Calendar disconnected.

### Local AI Unavailable

Use rule-based parser and show Local fallback where relevant.

### Invalid AI Interpretation

Show the invalid interpretation in Preview with Save disabled and edit/retry options.

### Notification Permission Not Granted

Settings and Task Detail should show reminders are off until permission is granted.

## Engineer Build Notes

- Build screens from local data first.
- Do not wait for Google Calendar to build task UI.
- Do not wait for local AI to build capture and preview UI.
- Keep parser output behind validation before saving.
- Use sample preview data only in SwiftUI previews, not as real user data.
- Keep each screen small enough to scan with one hand.
- Avoid nested cards and decorative containers.
