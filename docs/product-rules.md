# DoneLoop V1 Product Rules

This document defines the first version of DoneLoop in plain language. It is the product boundary for V1.

## One-Sentence Product Definition

DoneLoop is a local-first iPhone app that captures voice or text, turns messy thoughts into structured tasks, notes, reminders, and calendar blocks, then follows up until the user makes a decision.

## Who V1 Is For

V1 is for one person using their own iPhone to stop losing tasks and stop avoiding vague work.

The user may:

- Forget things because capture is not trusted.
- Procrastinate because tasks are too vague.
- Ignore reminders because they do not force a next decision.
- Put too much into notes or calendars without a clear follow-up loop.

DoneLoop should help this user capture quickly, clarify the next action, schedule only time-based work, and decide what happens next.

## What V1 Must Do

V1 must support this loop:

```text
Capture -> Structure -> Validate -> Save -> Schedule if needed -> Remind -> Decide
```

In practical terms, V1 must let the user:

1. Capture a messy thought by voice or text.
2. Review or edit the transcript or typed input.
3. Let local AI or a rule-based parser suggest structured items.
4. Review the suggested items before saving.
5. Save tasks, reminders, calendar blocks, notes, ideas, and brain dumps locally.
6. Sync only scheduled time-based work to Google Calendar.
7. Receive local reminders.
8. Choose Done, Snooze, Reschedule, Break down, Blocked, or Delete.

## Required Item Types

Every captured thought should become one or more of these item types.

### Task

A task is something the user can act on.

Example:

```text
Apply to Airbnb
```

A good task should have a clear title and, when possible, a next action.

### Reminder

A reminder is a task or prompt tied to a specific date or time.

Example:

```text
Remind me tonight at 8 to call Mom.
```

### Calendar Block

A calendar block is scheduled work time.

Example:

```text
Tomorrow at 10, block one hour to apply to Airbnb.
```

Calendar blocks can sync to Google Calendar.

### Note

A note is information the user wants to keep but does not need to act on right now.

Example:

```text
The recruiter said the next interview may be next week.
```

### Idea

An idea is a possible future action or project.

Example:

```text
Maybe build a weekly review screen later.
```

Ideas should not automatically become tasks unless the user chooses to convert them.

### Brain Dump

A brain dump is a messy collection of thoughts that may need cleanup later.

Example:

```text
Resume, Airbnb job, groceries, dentist, maybe plan weekend, fix portfolio.
```

V1 should save brain dumps and may suggest structured items, but it should not pretend every brain dump is already organized.

## Required Task Decisions

Every active task must eventually move through one of these decisions.

### Done

The user completed the task.

### Snooze

The user delays the task briefly.

Snooze should increase the task's snooze count. After repeated snoozes, DoneLoop should suggest shrinking the task.

### Reschedule

The user chooses a new date or time.

If the task has a Google Calendar event, rescheduling should eventually update that event.

### Break Down

The task is too large or vague, so the user asks DoneLoop to create a smaller next action.

Example:

```text
Original task: Apply to 5 jobs
Smaller task: Apply to 1 job
Next action: Open one saved job link
```

### Blocked

The user cannot continue because something is missing.

Example:

```text
Blocked because I need the job link first.
```

### Delete

The task is no longer useful and should be removed.

Delete is destructive and should require confirmation.

## Calendar Rules

DoneLoop owns tasks. Google Calendar only stores scheduled time.

Sync to Google Calendar only when the user gives a specific time or scheduling intent, such as:

- "tomorrow at 10"
- "tonight at 8"
- "every Monday"
- "block one hour"
- "schedule this"
- "remind me at"

Do not sync these to Google Calendar:

- Notes
- Ideas
- Vague tasks
- Someday items
- Brain dumps

Examples:

```text
Input: I should improve my resume.
Result: Create an unscheduled task in Inbox. Do not create a calendar event.
```

```text
Input: Block 45 minutes tomorrow at 7 PM to improve my resume.
Result: Create a task and a Google Calendar event.
```

## AI Rules

AI must not directly run the app.

AI or parser logic may suggest structured output. The app must validate that output before creating tasks, notes, reminders, calendar events, or notifications.

Required flow:

```text
User input -> Parser returns structured data -> App validates data -> App saves or updates local records
```

V1 must work without paid AI.

Preferred V1 order:

1. Local or on-device parser/model when available.
2. Rule-based parser as fallback.
3. Optional free cloud fallback only when local parsing fails.

## What V1 Is Not

DoneLoop V1 is not:

- A chatbot.
- A notes clone.
- A calendar clone.
- A Notion replacement.
- A complex life-planning app.
- A managed cloud AI product.
- A team productivity system.
- A full backend platform.
- A cross-device sync product.

If a feature does not directly support capture, structuring, scheduling, reminders, or decision loops, it should move to V2, V3, or backlog.

## V1 Success Criteria

V1 is successful when this exact path works:

```text
User says: Tomorrow at 10, block one hour to apply to Airbnb.
DoneLoop creates: a task, a scheduled calendar block, and a local reminder.
DoneLoop follows up until the user chooses Done, Snooze, Reschedule, Break down, Blocked, or Delete.
```

The app must still work if paid AI is unavailable.

## Product Guardrails

- Keep Capture fast.
- Keep Today focused.
- Keep Inbox for vague or unscheduled thoughts.
- Keep Google Calendar as a sync target, not the task database.
- Keep AI behind structured validation.
- Keep reminders decision-based.
- Keep language plain and non-judgmental.
- Keep V1 small enough to finish.
