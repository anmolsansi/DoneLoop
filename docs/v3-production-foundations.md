# V3 Production Foundations

V3 is the product roadmap for turning DoneLoop from a personal iPhone app into a commercial product. These plans are tracked in code as local Swift roadmap types in `DoneLoop/V3/V3ProductionFoundation.swift`.

This foundation is not a V1 feature launch. It documents production decisions so future engineers can add providers, sync, billing, and team features without changing the V1 rule: DoneLoop must work without paid AI or a backend.

## Product Boundary

V1 remains:

- Native iPhone app.
- Voice and text capture.
- Local parser first.
- Local storage.
- Google Calendar sync only for scheduled work.
- Local reminders.
- Required decision loop.

V3 must not pull these into V1:

- Account system.
- Billing.
- Managed cloud AI.
- Cross-device sync.
- Web dashboard.
- Team workspaces.
- Gmail scanning.
- External task-list ownership.

## OPE-122: AI Provider Selection

Goal:

Create a provider selection plan that supports local AI, free fallback, user-provided keys, and managed cloud AI later.

Implementation:

- `DLV3AIProviderKind` lists possible providers.
- `DLV3AIProviderMode` groups providers into Local Only, Local + Free Fallback, Bring Your Own Key, and Managed Cloud.
- `DLV3ProviderRouterPlan` preserves one routing rule: every AI call must pass through one internal interface.

Plain-language rule:

AI can suggest structured output, but the app must validate it before creating tasks, calendar events, reminders, or deletes.

## OPE-123: Bring Your Own Key Mode

Goal:

Document future user-key requirements without building the setting yet.

Implementation:

- `DLV3BYOKProviderRequirement` describes each external provider setup.
- User keys should be stored in Keychain.
- Local server mode should show the configured endpoint before use.

Plain-language rule:

The user pays the external provider and must understand what information is sent.

## OPE-124: Managed Cloud AI Mode

Goal:

Keep managed cloud AI as a future paid product mode.

Implementation:

- `DLV3ManagedCloudPlan` states that managed AI requires a backend, billing, privacy policy, and usage caps.

Plain-language rule:

Managed AI should ship only after personal retention is proven and the cost model is capped.

## OPE-125: Pricing Tiers And Usage Caps

Goal:

Capture the pricing structure without creating payments or subscriptions.

Implementation:

- `DLV3PricingTier` defines Free, Power User, Pro, and Team.
- `DLV3UsageCap` defines daily fallback, monthly managed AI, and background planning limits.

Plain-language rule:

V1 should never fail because the app has no billing system.

## OPE-126: Cross-Device Sync

Goal:

Describe what is needed before iPhone data can sync across devices.

Implementation:

- `DLV3CrossDeviceSyncPlan` requires accounts, encrypted transport, and conflict handling.
- Conflict policies include newest edit wins, ask user, and keep both.

Plain-language rule:

DoneLoop remains the source of truth. Calendar, Tasks, and Reminders are projections.

## OPE-127: Mac App

Goal:

Define the Mac app as a future companion surface.

Implementation:

- `DLV3ClientSurfacePlan` marks the Mac app as future work.
- It requires cloud sync and likely shared SwiftUI.

Plain-language rule:

Do not build the Mac app until the iPhone capture and reminder loop works.

## OPE-128: Web Dashboard

Goal:

Define the web dashboard as a future review and admin surface.

Implementation:

- `DLV3ClientSurfacePlan` marks the web dashboard as future work.
- It requires cloud sync, authentication, and backend APIs.

Plain-language rule:

A web dashboard should not replace the iPhone-first product.

## OPE-129: Gmail Integration

Goal:

Capture Gmail as a future opt-in extraction feature.

Implementation:

- `DLV3ExternalIntegrationPlan` requires explicit email permission.
- Gmail can suggest tasks but must not create them silently.

Plain-language rule:

Email content should only be scanned after the user clearly enables it.

## OPE-130: Google Tasks Optional Sync

Goal:

Document Google Tasks as an optional bridge, not the main task system.

Implementation:

- Google Tasks sync requires read/write permission.
- DoneLoop still owns status, snooze, missed, and decision-loop fields.

Plain-language rule:

Google Tasks can mirror tasks, but it must not own DoneLoop behavior.

## OPE-131: Apple Reminders Optional Sync

Goal:

Document Apple Reminders as an optional bridge.

Implementation:

- Reminders sync requires Reminders permission.
- DoneLoop writes external reminders as projections.

Plain-language rule:

Apple Reminders can help surface reminders, but DoneLoop owns the decision loop.

## OPE-132: Onboarding And Privacy Controls

Goal:

Define future onboarding and privacy controls in plain language.

Implementation:

- `DLV3OnboardingStep` covers promise, privacy mode, calendar, and decision loop education.
- `DLV3PrivacyControl` covers cloud fallback, active provider display, Gmail import, and analytics.

Plain-language rule:

Before anything leaves the device, the app must say what leaves and why.

## OPE-133: Team And Enterprise Features

Goal:

Keep team and enterprise work separate from the personal app.

Implementation:

- `DLV3TeamEnterprisePlan` requires organizations, roles, permissions, audit trail, and compliance policy.

Plain-language rule:

Do not add team setup, admin screens, or compliance work to the personal V1 app.

## Acceptance Checklist

- V3 plans are represented in local Swift types.
- The app still builds without any provider credentials.
- No backend is required.
- No billing dependency is added.
- No cloud provider is required.
- No team or enterprise UI is added to V1.
- Future engineers can see where provider, sync, integration, privacy, and pricing work should attach.
