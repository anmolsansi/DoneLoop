# DoneLoop V1 Design System

This document defines the reusable Calm Focus visual system for the native iOS V1 app.

It is intentionally small. V1 needs enough structure to build the first SwiftUI screens consistently without creating a heavy custom design framework.

## Design Principles

- Calm first, decisive second.
- Native iOS controls before custom controls.
- Compact layouts over decorative layouts.
- Clear status over visual drama.
- One-handed actions should be easy to reach.
- Red is reserved for destructive or serious states.
- Calendar is a sync status, not the center of the app.
- The next action should be easier to find than the task summary.

Avoid:

- Chat bubbles.
- Gradient blobs.
- Marketing hero sections.
- Web dashboard chrome.
- Nested cards.
- Oversized display type inside compact screens.
- Purple-heavy or beige-only palettes.

## Color Tokens

Use semantic color names in code. The exact hex values can be tuned once the SwiftUI app exists, but the relationships should stay stable.

| Token | Hex | Use |
| --- | --- | --- |
| `DLColor.background` | `#F8F6F0` | App background, warm off-white |
| `DLColor.surface` | `#FFFFFF` | Sheets, rows, elevated surfaces |
| `DLColor.surfaceMuted` | `#F1EEE6` | Grouped section backgrounds |
| `DLColor.textPrimary` | `#1F2421` | Main text |
| `DLColor.textSecondary` | `#5E665F` | Metadata, helper text |
| `DLColor.textTertiary` | `#8A928C` | Placeholder text |
| `DLColor.divider` | `#DEDAD0` | Hairline separators |
| `DLColor.primary` | `#557C64` | Primary actions, active tab |
| `DLColor.primaryPressed` | `#41624D` | Pressed primary state |
| `DLColor.primaryMuted` | `#DDE9E1` | Subtle primary backgrounds |
| `DLColor.attention` | `#B7791F` | Overdue and needs-attention states |
| `DLColor.attentionMuted` | `#F7E7C5` | Attention backgrounds |
| `DLColor.success` | `#2F7D4F` | Done and successful sync |
| `DLColor.successMuted` | `#DCECDF` | Success backgrounds |
| `DLColor.danger` | `#B9463F` | Delete and serious errors only |
| `DLColor.dangerMuted` | `#F4DAD7` | Destructive confirmation backgrounds |
| `DLColor.info` | `#4B6F90` | Calendar connected and neutral info |
| `DLColor.infoMuted` | `#DCE7EF` | Info backgrounds |

### Color Rules

- Use `primary` for the main path forward.
- Use `attention` for overdue, missed, and needs-decision states.
- Use `success` for Done and synced states.
- Use `danger` only for Delete, serious errors, and destructive confirmation.
- Do not use red for ordinary overdue tasks. Use amber attention.
- Do not use decorative gradients.

## Typography

Use the iOS system font. Do not introduce custom typefaces in V1.

| Token | iOS Style | Use |
| --- | --- | --- |
| `DLFont.largeTitle` | `.largeTitle.weight(.semibold)` | Main screen title when needed |
| `DLFont.title` | `.title2.weight(.semibold)` | Section-leading titles |
| `DLFont.headline` | `.headline` | Card and row titles |
| `DLFont.body` | `.body` | Main body text |
| `DLFont.callout` | `.callout` | Secondary row text |
| `DLFont.caption` | `.caption` | Metadata and badges |
| `DLFont.button` | `.body.weight(.semibold)` | Button labels |

### Type Rules

- Do not scale font size with viewport width.
- Letter spacing should stay at `0`.
- Use line limits for rows, but never hide critical next actions.
- Long task titles should wrap to two lines before truncating.
- The next action can be visually stronger than the summary.

## Spacing And Layout

| Token | Value | Use |
| --- | --- | --- |
| `DLSpacing.xs` | `4` | Tight icon/text gaps |
| `DLSpacing.sm` | `8` | Row internals |
| `DLSpacing.md` | `12` | Compact vertical rhythm |
| `DLSpacing.lg` | `16` | Screen padding and section gaps |
| `DLSpacing.xl` | `24` | Major section separation |
| `DLSpacing.xxl` | `32` | Capture mic separation |

### Radius

| Token | Value | Use |
| --- | --- | --- |
| `DLRadius.sm` | `4` | Badges, small controls |
| `DLRadius.md` | `8` | Cards, rows, panels |
| `DLRadius.full` | `999` | Mic button, pills, circular icons |

Cards should use `8px` radius or less. Circular icon buttons and the mic button can use full radius.

### Dividers And Shadows

- Prefer hairline dividers over shadows.
- Use shadows only for modal sheets or floating quick actions.
- Shadow should be subtle, not decorative.

## Icon Rules

Use SF Symbols in the native iOS app.

Suggested mappings:

| Meaning | SF Symbol |
| --- | --- |
| Capture | `mic.fill` |
| Stop recording | `stop.fill` |
| Text capture | `text.cursor` |
| Today | `sun.max` |
| Inbox | `tray` |
| Settings | `gearshape` |
| Done | `checkmark` |
| Snooze | `clock` |
| Reschedule | `calendar.badge.clock` |
| Break down | `list.bullet.indent` |
| Blocked | `exclamationmark.octagon` |
| Delete | `trash` |
| Calendar synced | `calendar.badge.checkmark` |
| Calendar disconnected | `calendar.badge.exclamationmark` |
| Warning | `exclamationmark.triangle` |
| Privacy/local | `lock` |

Icon buttons should still have accessible labels.

## Core Components

### App Shell

Use a native tab bar with four tabs:

- Capture
- Today
- Inbox
- Settings

Default tab: Capture.

Active tab color: `DLColor.primary`.

Inactive tab color: `DLColor.textSecondary`.

### Screen Header

Use for primary screens.

Required content:

- Screen title.
- Optional compact status or quick action.

Rules:

- Keep titles short.
- Do not use marketing copy.
- Avoid giant headers that push useful content below the fold.

### Section Header

Use for grouped content such as Top 3, Calendar Blocks, Needs Decision, and Overdue.

Required content:

- Section title.
- Optional count.
- Optional trailing action.

### List Row

Use for recent captures, Inbox items, Settings rows, and compact task rows.

Required states:

- Default.
- Pressed.
- Disabled.
- Loading.

Required content options:

- Leading icon or type chip.
- Title.
- Subtitle or metadata.
- Trailing status badge, value, or chevron.

Long title behavior:

- Wrap title to two lines.
- Keep trailing status visible.
- If subtitle is long, truncate after two lines.

### Task Row

Use in Today, Inbox, and search/future lists.

Required content:

- Task title.
- Next action when available.
- Time or schedule status.
- Status badge.
- Priority or attention indicator only when useful.

States:

- Default.
- Overdue.
- Pending decision.
- Blocked.
- Done.
- Calendar sync failed.

Visual rules:

- Overdue uses `attention`, not `danger`.
- Done uses muted success styling.
- Blocked uses attention or neutral warning, not destructive red.

### Card

Use only when grouping a repeated item or modal content.

Do not place cards inside cards.

Required states:

- Default.
- Pressed/selectable.
- Disabled.
- Error.

Styling:

- `DLColor.surface`.
- `DLRadius.md`.
- Hairline border or subtle divider.
- Minimal shadow only if floating above content.

### Primary Button

Use for the main action in a screen or sheet.

Examples:

- Save Items.
- Interpret.
- Connect Calendar.
- Schedule Starter Step.

States:

- Default: sage background, white text.
- Pressed: darker sage.
- Disabled: muted surface with tertiary text.
- Loading: disabled with progress indicator.

Rules:

- Keep labels short.
- One primary button per screen section when possible.

### Secondary Button

Use for non-primary safe actions.

Examples:

- Retry.
- Edit.
- Open Inbox.

Style:

- Clear or muted surface.
- Primary or textPrimary label.
- Hairline border when needed.

### Destructive Button

Use only for destructive actions.

Examples:

- Delete task.
- Disconnect Calendar if data loss or sync removal is possible.

Style:

- Danger text or danger background depending on severity.
- Confirmation required for irreversible actions.

### Icon Button

Use for compact tool actions.

Required:

- SF Symbol.
- Accessible label.
- Minimum tap target of 44x44 points.

Examples:

- Quick capture.
- Edit.
- Retry sync.
- Close sheet.

### Segmented Control

Use for mutually exclusive settings.

V1 examples:

- AI Mode: Local Only, Local + Fallback, BYOK.

Rules:

- Keep labels short.
- If a mode is future-only, disable it and mark as future in the row description.

### Toggle Row

Use for binary settings.

Examples:

- Reminders enabled.
- Cloud fallback enabled.

Required content:

- Title.
- Optional short description.
- Native toggle.

### Status Badge

Use for task and sync states.

| Status | Text | Color |
| --- | --- | --- |
| Done | `Done` | Success |
| Overdue | `Overdue` | Attention |
| Blocked | `Blocked` | Attention |
| Pending decision | `Needs decision` | Attention |
| Calendar pending | `Calendar pending` | Info |
| Calendar synced | `Synced` | Success |
| Calendar failed | `Sync failed` | Danger or attention depending severity |
| Calendar disconnected | `Disconnected` | Text secondary |
| Local parsing | `Local` | Primary muted |
| Rule fallback | `Rule-based` | Info muted |
| Cloud fallback | `Cloud fallback` | Attention muted |

Rules:

- Badges should be compact.
- Do not use badge color as the only signal; include readable text.

### Empty State

Required content:

- Short title.
- Optional one-sentence helper.
- Optional single action.

Examples:

```text
Inbox is clear.
```

```text
Nothing scheduled. Capture something or clear your Inbox.
```

Rules:

- No motivational quotes.
- No long feature explanations.

### Error State

Required content:

- What happened.
- Whether local data was saved.
- One next action if available.

Examples:

```text
Saved locally. Calendar sync failed.
```

```text
This interpretation needs a time before it can go on your calendar.
```

### Bottom Sheet

Use for Reminder Decision Sheet, edit flows, and confirmation.

Required:

- Clear title.
- Task or item context.
- Primary action area.
- Cancel or close action.

Rules:

- Keep sheet content short.
- Important actions must not require scrolling on common iPhone sizes.
- Delete confirmations should be explicit.

## Decision Buttons

Decision buttons are central to DoneLoop. They must be visible, readable, and easy to tap.

### Done

- Icon: `checkmark`
- Color: success
- Meaning: task is complete.

### Snooze

- Icon: `clock`
- Color: primary or info
- Meaning: delay briefly.

### Reschedule

- Icon: `calendar.badge.clock`
- Color: info
- Meaning: choose a new time.

### Break Down

- Icon: `list.bullet.indent`
- Color: primary
- Meaning: create a smaller next action.

### Blocked

- Icon: `exclamationmark.octagon`
- Color: attention
- Meaning: something prevents progress.

### Delete

- Icon: `trash`
- Color: danger
- Meaning: remove the task.
- Confirmation: required.

### Layout Rules

On iPhone:

- Use a 2-column grid in sheets when space allows.
- Use full-width rows if labels wrap poorly.
- Keep Delete visually separated from the safe choices.
- Minimum tap target: 44x44 points.

## Component Edge Cases

### Long Task Titles

- Wrap to two lines in rows.
- Use full title in Task Detail.
- Do not let title overlap badges or action buttons.

### Empty Values

Use plain placeholders:

- `No time set`
- `No next action yet`
- `Not scheduled`
- `Calendar disconnected`

### Disabled Actions

Disabled actions should explain why when tapped or when shown in context.

Examples:

- Save disabled because interpretation is invalid.
- Calendar sync disabled because Calendar is disconnected.

### Overdue State

Use attention styling.

Do not use red unless data loss, destructive action, or serious failure is involved.

### Blocked State

Use attention styling and show the blocker reason when available.

### Calendar Connected

Show `Synced` or selected calendar where useful. Do not make Calendar the visual center of the task.

### Calendar Disconnected

Show `Disconnected` or `Saved locally`.

The user should still be able to create and manage tasks.

## SwiftUI Implementation Notes

When the SwiftUI project exists, create a small design-system layer with names like:

- `DLColor`
- `DLSpacing`
- `DLRadius`
- `DLFont`
- `DLPrimaryButton`
- `DLSecondaryButton`
- `DLDestructiveButton`
- `DLIconButton`
- `DLStatusBadge`
- `DLTaskRow`
- `DLListRow`
- `DLEmptyState`
- `DLErrorState`
- `DLDecisionButton`
- `DLBottomSheetContent`

Keep these as lightweight SwiftUI views and extensions. Do not add a separate design-system package for V1 unless the app grows enough to need it.

## Preview Requirements

When components are implemented, preview them on:

- Small iPhone size.
- Large iPhone size.
- Light mode first.
- Dynamic Type at a larger size where practical.

Preview required states:

- Long task title.
- Empty value.
- Disabled action.
- Overdue task.
- Blocked task.
- Calendar connected.
- Calendar disconnected.
- Sync failed.
- Done state.

## V1 Completion Checklist

The design system is ready for V1 implementation when it includes:

- Color tokens.
- Typography tokens.
- Spacing and radius tokens.
- List row pattern.
- Task row pattern.
- Card pattern.
- Primary, secondary, destructive, and icon buttons.
- Segmented control guidance.
- Toggle row guidance.
- Status badge pattern.
- Empty state pattern.
- Error state pattern.
- Bottom sheet pattern.
- Six decision button definitions.
- Edge-case handling for long text, empty values, disabled actions, overdue, blocked, connected, and disconnected states.
