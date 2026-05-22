# DoneLoop Roadmap Backlog

This document keeps future work visible without moving it into the V1 build scope.

## V1 Boundary

V1 remains a native iPhone MVP:

- Voice and text capture.
- Local parser and validation.
- Local storage.
- Google Calendar sync for scheduled work only.
- Local notifications.
- Reminder decision loop.
- Today, Inbox, Task Detail, Capture, and Settings.

V1 should not include managed cloud AI, team accounts, billing, cross-device sync, Notion task management, a web dashboard, or a backend-first architecture.

## V2 Backlog

V2 is about organization and review after the V1 loop works.

- Weekly review: summarize completed, snoozed, blocked, and missed work.
- Procrastination pattern detection: show repeated snooze/missed patterns.
- Project grouping: group tasks without turning the app into project management software.
- Notion export: archive summaries, ideas, and long-term notes only.
- Search: find tasks, captures, notes, ideas, and brain dumps.
- Recurring routines: support repeated personal routines.
- Better task shrinking: improve deterministic shrinking with local/free AI.
- Stuck-task detection: surface tasks that repeatedly avoid resolution.
- Semantic note organization: cluster notes and brain dumps for later review.

## V3 Production Roadmap

V3 is about turning a personal app into a product after V1 proves retention.

- AI provider selection.
- Bring Your Own Key mode.
- Managed cloud AI mode.
- Pricing tiers and usage caps.
- Cross-device sync.
- Mac app.
- Web dashboard.
- Gmail integration.
- Google Tasks optional sync.
- Apple Reminders optional sync.
- Onboarding and privacy controls.
- Team and enterprise features.

These are intentionally not required for V1.

## AI And Privacy Modes

Local Only:
Runs local parsing and app actions on the device. Best for privacy-first, offline, and free use.

Local + Free Fallback:
Uses local parsing first. A free cloud fallback is optional and only used when local parsing fails or the user explicitly allows it.

Bring Your Own Key:
Future power-user mode. Users connect their own provider keys for OpenAI, Claude, Gemini, OpenRouter, or local server/Ollama.

Managed Cloud AI:
Future paid SaaS mode. DoneLoop controls provider quality, usage caps, billing, and privacy policy. This must not be the default V1 architecture.

Plain-language privacy rule:

If cloud fallback is off, captures and task data should stay on the device. If cloud fallback is on, Settings must explain what can leave the device before the user enables it.
