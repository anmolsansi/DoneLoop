# DoneLoop V2 Backlog Foundations

This document explains the V2 foundation added for OPE-113 through OPE-121. These are local, backend-free building blocks. They do not change the V1 user flow and do not turn DoneLoop into a project-management app, a Notion replacement, or a cloud-first product.

## Scope

The V2 foundation covers:

- Weekly review summaries.
- Procrastination pattern detection.
- Lightweight project grouping.
- Notion archive export formatting.
- Local search across stored data.
- Recurring routine draft generation.
- Better task shrink suggestions.
- Stuck-task detection.
- Semantic note and idea clustering.

The implementation lives in `DoneLoop/V2/V2BacklogFoundation.swift`.

## OPE-113: Weekly Review

The weekly review engine creates a local summary for the last seven days. It counts completed, snoozed, blocked, missed, and deleted work. It also includes stuck tasks, procrastination patterns, and one plain-language suggested focus.

This uses local task data only. It does not require cloud AI or a backend.

## OPE-114: Procrastination Pattern Detection

The pattern detector flags tasks that are repeatedly snoozed, missed, or blocked. Each pattern includes a reason and a suggested decision such as shrink, reschedule, name the blocker, or delete.

The copy is direct and practical. It avoids shaming language.

## OPE-115: Project Grouping

The grouping engine derives lightweight project groups from task categories and meaningful words in task, note, or idea text. This gives the app a future organization layer without adding project-management complexity to V1.

Groups are derived, not persisted as a new source of truth.

## OPE-116: Notion Archive Export

The archive exporter produces Markdown for weekly review summaries. This keeps Notion as an archive/export destination only.

DoneLoop remains the active task and decision system.

## OPE-117: Local Search

The search engine scans local tasks, captures, notes, and ideas. Results include item type, title, detail, and matched text. Search is simple text matching for V2 foundations; semantic search can be added later.

## OPE-118: Recurring Routines

The routine engine creates routine drafts from existing tasks. A draft includes title, next action, frequency, preferred hour, and default duration.

This is a foundation only. It does not yet schedule recurring notifications or calendar events.

## OPE-119: Better Task Shrinking

The shrink engine returns deterministic local suggestions. It preserves the V1 fallback and adds a clear structure for future local/free AI provider use.

Example:

- Original: Apply to 5 jobs.
- Smaller task: Apply to 1 job.
- Next action: Open one saved job link.

## OPE-120: Stuck-Task Detection

The stuck-task detector flags unfinished tasks that have repeated snoozes, blocked status, or overdue missed reminders. Each stuck task includes a suggested decision.

This should surface in review, not as noisy daily nagging.

## OPE-121: Semantic Note Organization

The note organizer clusters notes and ideas by category, summary, suggested action, or meaningful title words. It keeps notes secondary to tasks and decisions.

The output suggests whether a cluster should simply be reviewed or whether one idea should become a task.

## Non-Goals

- No cloud AI requirement.
- No Notion task sync.
- No new V1 screens.
- No backend.
- No accounts.
- No heavy project-management surface.

## Validation

The foundation is validated by:

- Swift typechecking.
- Xcode project lint.
- Generic iOS simulator build.
- Plain-language documentation review.
