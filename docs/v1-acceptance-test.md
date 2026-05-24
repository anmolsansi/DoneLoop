# DoneLoop V1 End-to-End Acceptance Test

This checklist verifies the V1 product path. It is intentionally written as a user journey, not as isolated engineering checks.

## Core Scenario

Test sentence:

> Tomorrow at 10, block one hour to apply to Airbnb.

Expected result:

- DoneLoop captures the sentence by voice or text.
- The parser creates a task and a scheduled calendar block.
- The app validates the structured output before saving.
- The task is stored locally.
- The scheduled block is eligible for Google Calendar sync.
- A local notification is scheduled when notification permission is granted.
- Today shows the scheduled work.
- Opening the reminder shows the decision sheet.
- The user can choose Done, Snooze, Reschedule, Break down, Blocked, or Delete.

## Manual Test

1. Launch the app on an iPhone simulator or device.
2. Open Capture.
3. Use text capture with the core test sentence.
4. Confirm the interpretation preview shows structured items.
5. Save the items.
6. Open Today.
7. Confirm scheduled work appears in Calendar Blocks or Top 3.
8. Open the task detail.
9. Confirm schedule, calendar status, reminder status, snooze count, missed count, and next action are visible.
10. Enable local reminders from Settings and grant notification permission.
11. Reschedule the task to a near-future time.
12. Confirm the reminder status changes to scheduled.
13. Open the decision sheet.
14. Test each action on a fresh task or reset local data between runs:
    - Done marks the task complete and cancels the reminder.
    - Snooze increments snooze count and schedules a new reminder.
    - Reschedule changes the task time and reschedules reminder/calendar state.
    - Break down shrinks the task into a smaller next action.
    - Blocked marks the task blocked and cancels the reminder.
    - Delete requires confirmation and removes the task from active views.

## Additional Checks

- Text capture works without voice input.
- A vague task such as "I should improve my resume" stays in Inbox.
- Notes, ideas, and brain dumps do not create calendar events.
- Calendar disconnected state does not prevent local saving.
- Notification permission denied state is visible in Settings and Task Detail.
- Invalid parser output is rejected before item creation.
- The app works without paid AI.
- Local data persists after app restart.

## Current V1 Caveats

- Google Calendar sync is implemented behind a local adapter boundary. Real OAuth and Calendar API calls still need production credentials and package integration.
- Voice transcription uses the native speech flow already in the app, but automated simulator verification should use text capture unless microphone permissions and simulator audio input are configured.
- Notification delivery timing must be manually verified on a device or simulator because command-line typechecks cannot prove that iOS displays banners.
