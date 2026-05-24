import Foundation

enum DLV3AIProviderKind: String, CaseIterable, Equatable {
    case appleLocal
    case gemmaLocal
    case functionCallingLocal
    case ruleBased
    case gemini
    case openAI
    case anthropic
    case openRouter
    case localServer
    case managed
}

enum DLV3AIProviderMode: String, CaseIterable, Equatable {
    case localOnly
    case localWithFreeFallback
    case bringYourOwnKey
    case managedCloud

    var isFutureOnly: Bool {
        switch self {
        case .localOnly, .localWithFreeFallback:
            false
        case .bringYourOwnKey, .managedCloud:
            true
        }
    }
}

struct DLV3AIProviderOption: Identifiable, Equatable {
    var id: DLV3AIProviderKind
    var displayName: String
    var mode: DLV3AIProviderMode
    var requiresNetwork: Bool
    var requiresUserKey: Bool
    var requiresManagedAccount: Bool
    var allowedInPersonalV1: Bool
    var plainLanguageUse: String
    var privacyNote: String
}

struct DLV3ProviderRouterPlan: Equatable {
    var defaultMode: DLV3AIProviderMode
    var supportedMethods: [String]
    var providerOptions: [DLV3AIProviderOption]
    var routingRule: String
    var validationRule: String
}

enum DLV3SecretStorageLevel: String, Equatable {
    case none
    case keychain
    case serverVault
}

struct DLV3BYOKProviderRequirement: Identifiable, Equatable {
    var id: DLV3AIProviderKind
    var displayName: String
    var secretStorage: DLV3SecretStorageLevel
    var setupRequirement: String
    var userRiskCopy: String
    var shouldShipBeforeV1: Bool
}

struct DLV3ManagedCloudPlan: Equatable {
    var requiresBackend: Bool
    var requiresBilling: Bool
    var requiresPrivacyPolicy: Bool
    var requiresUsageCaps: Bool
    var shouldShipBeforeV1: Bool
    var launchRule: String
}

struct DLV3PricingTier: Identifiable, Equatable {
    enum TierID: String, Equatable {
        case free
        case powerUser
        case pro
        case team
    }

    var id: TierID
    var displayName: String
    var intendedUser: String
    var includedModes: [DLV3AIProviderMode]
    var usageCapSummary: String
    var shouldBlockV1: Bool
}

struct DLV3UsageCap: Identifiable, Equatable {
    var id: String
    var label: String
    var appliesToMode: DLV3AIProviderMode
    var limitDescription: String
    var fallbackBehavior: String
}

enum DLV3SyncConflictPolicy: String, CaseIterable, Equatable {
    case newestEditWins
    case askUser
    case keepBoth
}

struct DLV3CrossDeviceSyncPlan: Equatable {
    var requiresAccountSystem: Bool
    var requiresEncryptedTransport: Bool
    var conflictPolicies: [DLV3SyncConflictPolicy]
    var sourceOfTruth: String
    var shouldShipBeforeV1: Bool
}

enum DLV3ClientSurface: String, CaseIterable, Equatable {
    case iPhone
    case mac
    case webDashboard
}

struct DLV3ClientSurfacePlan: Identifiable, Equatable {
    var id: DLV3ClientSurface
    var displayName: String
    var purpose: String
    var requiresCloudSync: Bool
    var requiresSharedSwiftUI: Bool
    var shouldShipBeforeV1: Bool
}

enum DLV3ExternalIntegrationKind: String, CaseIterable, Equatable {
    case gmail
    case googleTasks
    case appleReminders
}

struct DLV3ExternalIntegrationPlan: Identifiable, Equatable {
    var id: DLV3ExternalIntegrationKind
    var displayName: String
    var purpose: String
    var requiredPermission: String
    var sourceOfTruthRule: String
    var reviewBeforeSave: Bool
    var shouldShipBeforeV1: Bool
}

struct DLV3OnboardingStep: Identifiable, Equatable {
    var id: String
    var title: String
    var plainLanguageGoal: String
    var requiredBeforeCapture: Bool
}

struct DLV3PrivacyControl: Identifiable, Equatable {
    var id: String
    var title: String
    var defaultValue: Bool
    var explanation: String
    var mustBeVisibleBeforeCloudUse: Bool
}

struct DLV3TeamEnterprisePlan: Equatable {
    var requiresOrganizations: Bool
    var requiresRolesAndPermissions: Bool
    var requiresAuditTrail: Bool
    var requiresCompliancePolicy: Bool
    var shouldShipBeforeV1: Bool
    var boundaryRule: String
}

struct DLV3ProductionRoadmap: Equatable {
    var providerRouter: DLV3ProviderRouterPlan
    var byokRequirements: [DLV3BYOKProviderRequirement]
    var managedCloud: DLV3ManagedCloudPlan
    var pricingTiers: [DLV3PricingTier]
    var usageCaps: [DLV3UsageCap]
    var syncPlan: DLV3CrossDeviceSyncPlan
    var clientSurfaces: [DLV3ClientSurfacePlan]
    var externalIntegrations: [DLV3ExternalIntegrationPlan]
    var onboardingSteps: [DLV3OnboardingStep]
    var privacyControls: [DLV3PrivacyControl]
    var teamEnterprise: DLV3TeamEnterprisePlan
}

enum DLV3ProductionRoadmapEngine {
    static func makeRoadmap() -> DLV3ProductionRoadmap {
        DLV3ProductionRoadmap(
            providerRouter: makeProviderRouterPlan(),
            byokRequirements: makeBYOKRequirements(),
            managedCloud: makeManagedCloudPlan(),
            pricingTiers: makePricingTiers(),
            usageCaps: makeUsageCaps(),
            syncPlan: makeCrossDeviceSyncPlan(),
            clientSurfaces: makeClientSurfacePlans(),
            externalIntegrations: makeExternalIntegrationPlans(),
            onboardingSteps: makeOnboardingSteps(),
            privacyControls: makePrivacyControls(),
            teamEnterprise: makeTeamEnterprisePlan()
        )
    }

    static func makeProviderRouterPlan() -> DLV3ProviderRouterPlan {
        DLV3ProviderRouterPlan(
            defaultMode: .localOnly,
            supportedMethods: [
                "parseCommand(input)",
                "summarizeBrainDump(input)",
                "breakDownTask(task)",
                "suggestTopThree(tasks)"
            ],
            providerOptions: [
                DLV3AIProviderOption(
                    id: .appleLocal,
                    displayName: "Apple on-device model",
                    mode: .localOnly,
                    requiresNetwork: false,
                    requiresUserKey: false,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: true,
                    plainLanguageUse: "Use the phone model to structure short captures.",
                    privacyNote: "Capture text stays on the device."
                ),
                DLV3AIProviderOption(
                    id: .gemmaLocal,
                    displayName: "Gemma local model",
                    mode: .localOnly,
                    requiresNetwork: false,
                    requiresUserKey: false,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: true,
                    plainLanguageUse: "Run an open local model for parsing and summaries.",
                    privacyNote: "Model download and battery impact must be shown in Settings."
                ),
                DLV3AIProviderOption(
                    id: .functionCallingLocal,
                    displayName: "Local function calling model",
                    mode: .localOnly,
                    requiresNetwork: false,
                    requiresUserKey: false,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: true,
                    plainLanguageUse: "Convert messy language into safe app actions.",
                    privacyNote: "The app still validates every action before saving."
                ),
                DLV3AIProviderOption(
                    id: .ruleBased,
                    displayName: "Rule parser",
                    mode: .localOnly,
                    requiresNetwork: false,
                    requiresUserKey: false,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: true,
                    plainLanguageUse: "Handle simple dates, reminders, and task creation without a model.",
                    privacyNote: "No data leaves the device."
                ),
                DLV3AIProviderOption(
                    id: .gemini,
                    displayName: "Gemini fallback",
                    mode: .localWithFreeFallback,
                    requiresNetwork: true,
                    requiresUserKey: false,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: true,
                    plainLanguageUse: "Optional fallback when local parsing cannot understand the capture.",
                    privacyNote: "Settings must explain that capture text may leave the device."
                ),
                DLV3AIProviderOption(
                    id: .openAI,
                    displayName: "OpenAI key",
                    mode: .bringYourOwnKey,
                    requiresNetwork: true,
                    requiresUserKey: true,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: false,
                    plainLanguageUse: "Power users can route advanced planning through their own key.",
                    privacyNote: "The user pays the provider and accepts that provider policy."
                ),
                DLV3AIProviderOption(
                    id: .anthropic,
                    displayName: "Claude key",
                    mode: .bringYourOwnKey,
                    requiresNetwork: true,
                    requiresUserKey: true,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: false,
                    plainLanguageUse: "Power users can connect their own Claude key.",
                    privacyNote: "Keys must be stored securely and never logged."
                ),
                DLV3AIProviderOption(
                    id: .openRouter,
                    displayName: "OpenRouter key",
                    mode: .bringYourOwnKey,
                    requiresNetwork: true,
                    requiresUserKey: true,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: false,
                    plainLanguageUse: "Power users can choose models through one external router.",
                    privacyNote: "Provider choice and routing must be visible before use."
                ),
                DLV3AIProviderOption(
                    id: .localServer,
                    displayName: "Local server",
                    mode: .bringYourOwnKey,
                    requiresNetwork: true,
                    requiresUserKey: false,
                    requiresManagedAccount: false,
                    allowedInPersonalV1: false,
                    plainLanguageUse: "Advanced users can connect a self-hosted model.",
                    privacyNote: "The app should show the server address and explain what is sent."
                ),
                DLV3AIProviderOption(
                    id: .managed,
                    displayName: "Managed DoneLoop AI",
                    mode: .managedCloud,
                    requiresNetwork: true,
                    requiresUserKey: false,
                    requiresManagedAccount: true,
                    allowedInPersonalV1: false,
                    plainLanguageUse: "Paid product mode with provider quality handled by the service.",
                    privacyNote: "Requires usage limits, account data, and a published privacy policy."
                )
            ],
            routingRule: "Every AI call must pass through one router interface. The app executes only validated structured output.",
            validationRule: "No provider can directly create tasks, calendar events, notifications, or deletes."
        )
    }

    static func makeBYOKRequirements() -> [DLV3BYOKProviderRequirement] {
        [
            DLV3BYOKProviderRequirement(
                id: .openAI,
                displayName: "OpenAI",
                secretStorage: .keychain,
                setupRequirement: "User pastes an API key and chooses a model.",
                userRiskCopy: "Requests are billed to the user's provider account.",
                shouldShipBeforeV1: false
            ),
            DLV3BYOKProviderRequirement(
                id: .anthropic,
                displayName: "Claude",
                secretStorage: .keychain,
                setupRequirement: "User pastes an API key and chooses a supported Claude model.",
                userRiskCopy: "Task text can be sent to Anthropic when this provider is active.",
                shouldShipBeforeV1: false
            ),
            DLV3BYOKProviderRequirement(
                id: .gemini,
                displayName: "Gemini",
                secretStorage: .keychain,
                setupRequirement: "User either enables fallback or adds their own API key.",
                userRiskCopy: "Free-tier and paid-tier behavior must be explained separately.",
                shouldShipBeforeV1: false
            ),
            DLV3BYOKProviderRequirement(
                id: .openRouter,
                displayName: "OpenRouter",
                secretStorage: .keychain,
                setupRequirement: "User pastes an API key and selects a routeable model.",
                userRiskCopy: "A third-party router receives the request.",
                shouldShipBeforeV1: false
            ),
            DLV3BYOKProviderRequirement(
                id: .localServer,
                displayName: "Local server",
                secretStorage: .none,
                setupRequirement: "User enters a local endpoint URL and tests connectivity.",
                userRiskCopy: "Data is sent to the configured server address.",
                shouldShipBeforeV1: false
            )
        ]
    }

    static func makeManagedCloudPlan() -> DLV3ManagedCloudPlan {
        DLV3ManagedCloudPlan(
            requiresBackend: true,
            requiresBilling: true,
            requiresPrivacyPolicy: true,
            requiresUsageCaps: true,
            shouldShipBeforeV1: false,
            launchRule: "Ship only after personal retention is proven and the cost model is capped."
        )
    }

    static func makePricingTiers() -> [DLV3PricingTier] {
        [
            DLV3PricingTier(
                id: .free,
                displayName: "Free",
                intendedUser: "Privacy-first personal users.",
                includedModes: [.localOnly],
                usageCapSummary: "No managed AI allowance. Local storage and basic Calendar sync only.",
                shouldBlockV1: false
            ),
            DLV3PricingTier(
                id: .powerUser,
                displayName: "Power User",
                intendedUser: "Users who want advanced providers without DoneLoop paying inference cost.",
                includedModes: [.localOnly, .localWithFreeFallback, .bringYourOwnKey],
                usageCapSummary: "User-paid external calls. App limits retries and background calls.",
                shouldBlockV1: false
            ),
            DLV3PricingTier(
                id: .pro,
                displayName: "Pro",
                intendedUser: "Non-technical users who want managed quality.",
                includedModes: [.localOnly, .managedCloud],
                usageCapSummary: "Managed calls capped by subscription plan.",
                shouldBlockV1: false
            ),
            DLV3PricingTier(
                id: .team,
                displayName: "Team",
                intendedUser: "Organizations with shared work and admin needs.",
                includedModes: [.managedCloud],
                usageCapSummary: "Workspace caps, admin controls, and audit needs.",
                shouldBlockV1: false
            )
        ]
    }

    static func makeUsageCaps() -> [DLV3UsageCap] {
        [
            DLV3UsageCap(
                id: "free-fallback-daily",
                label: "Daily fallback limit",
                appliesToMode: .localWithFreeFallback,
                limitDescription: "Limit fallback calls per day to avoid hidden cost or privacy surprises.",
                fallbackBehavior: "Use the local rule parser and show a review state."
            ),
            DLV3UsageCap(
                id: "managed-monthly",
                label: "Monthly managed AI allowance",
                appliesToMode: .managedCloud,
                limitDescription: "Cap paid inference by tier and reset monthly.",
                fallbackBehavior: "Continue local mode and ask the user to upgrade or wait."
            ),
            DLV3UsageCap(
                id: "background-planning",
                label: "Background planning limit",
                appliesToMode: .managedCloud,
                limitDescription: "Prevent unbounded weekly reviews, search indexing, or proactive suggestions.",
                fallbackBehavior: "Queue work until the user opens the app."
            )
        ]
    }

    static func makeCrossDeviceSyncPlan() -> DLV3CrossDeviceSyncPlan {
        DLV3CrossDeviceSyncPlan(
            requiresAccountSystem: true,
            requiresEncryptedTransport: true,
            conflictPolicies: [.newestEditWins, .askUser, .keepBoth],
            sourceOfTruth: "DoneLoop remains the source of truth. Calendar, Tasks, and Reminders are projections.",
            shouldShipBeforeV1: false
        )
    }

    static func makeClientSurfacePlans() -> [DLV3ClientSurfacePlan] {
        [
            DLV3ClientSurfacePlan(
                id: .iPhone,
                displayName: "iPhone app",
                purpose: "Primary capture, reminder, and decision loop.",
                requiresCloudSync: false,
                requiresSharedSwiftUI: false,
                shouldShipBeforeV1: true
            ),
            DLV3ClientSurfacePlan(
                id: .mac,
                displayName: "Mac app",
                purpose: "Desktop review, planning, and keyboard-heavy cleanup.",
                requiresCloudSync: true,
                requiresSharedSwiftUI: true,
                shouldShipBeforeV1: false
            ),
            DLV3ClientSurfacePlan(
                id: .webDashboard,
                displayName: "Web dashboard",
                purpose: "Browser access for review, search, and team/admin use.",
                requiresCloudSync: true,
                requiresSharedSwiftUI: false,
                shouldShipBeforeV1: false
            )
        ]
    }

    static func makeExternalIntegrationPlans() -> [DLV3ExternalIntegrationPlan] {
        [
            DLV3ExternalIntegrationPlan(
                id: .gmail,
                displayName: "Gmail",
                purpose: "Extract candidate tasks from email only after explicit user review.",
                requiredPermission: "Google email read permission with clear opt-in.",
                sourceOfTruthRule: "Email can suggest tasks but cannot create them silently.",
                reviewBeforeSave: true,
                shouldShipBeforeV1: false
            ),
            DLV3ExternalIntegrationPlan(
                id: .googleTasks,
                displayName: "Google Tasks",
                purpose: "Optional bridge for users who already keep task lists in Google.",
                requiredPermission: "Google Tasks read/write permission.",
                sourceOfTruthRule: "DoneLoop owns status, snooze, missed, and decision-loop fields.",
                reviewBeforeSave: true,
                shouldShipBeforeV1: false
            ),
            DLV3ExternalIntegrationPlan(
                id: .appleReminders,
                displayName: "Apple Reminders",
                purpose: "Optional bridge into the user's existing reminder habit.",
                requiredPermission: "Reminders permission.",
                sourceOfTruthRule: "DoneLoop stores task truth and writes reminders as external projections.",
                reviewBeforeSave: true,
                shouldShipBeforeV1: false
            )
        ]
    }

    static func makeOnboardingSteps() -> [DLV3OnboardingStep] {
        [
            DLV3OnboardingStep(
                id: "promise",
                title: "Say what is on your mind",
                plainLanguageGoal: "Explain that DoneLoop captures, structures, and follows up until a decision is made.",
                requiredBeforeCapture: false
            ),
            DLV3OnboardingStep(
                id: "privacy-mode",
                title: "Choose privacy mode",
                plainLanguageGoal: "Explain local-only, optional fallback, and future paid provider modes.",
                requiredBeforeCapture: true
            ),
            DLV3OnboardingStep(
                id: "calendar",
                title: "Connect calendar when needed",
                plainLanguageGoal: "Explain that only scheduled work creates calendar events.",
                requiredBeforeCapture: false
            ),
            DLV3OnboardingStep(
                id: "decision-loop",
                title: "Every reminder needs a decision",
                plainLanguageGoal: "Show Done, Snooze, Reschedule, Break down, Blocked, and Delete.",
                requiredBeforeCapture: false
            )
        ]
    }

    static func makePrivacyControls() -> [DLV3PrivacyControl] {
        [
            DLV3PrivacyControl(
                id: "cloud-fallback",
                title: "Allow cloud fallback",
                defaultValue: false,
                explanation: "When off, capture text should stay on the device.",
                mustBeVisibleBeforeCloudUse: true
            ),
            DLV3PrivacyControl(
                id: "provider-routing",
                title: "Show active AI provider",
                defaultValue: true,
                explanation: "The user should know which provider handled a capture.",
                mustBeVisibleBeforeCloudUse: true
            ),
            DLV3PrivacyControl(
                id: "gmail-import",
                title: "Allow email scanning",
                defaultValue: false,
                explanation: "Email should never be scanned until the user explicitly enables it.",
                mustBeVisibleBeforeCloudUse: true
            ),
            DLV3PrivacyControl(
                id: "analytics",
                title: "Allow product analytics",
                defaultValue: false,
                explanation: "Personal task content should not be included in analytics.",
                mustBeVisibleBeforeCloudUse: false
            )
        ]
    }

    static func makeTeamEnterprisePlan() -> DLV3TeamEnterprisePlan {
        DLV3TeamEnterprisePlan(
            requiresOrganizations: true,
            requiresRolesAndPermissions: true,
            requiresAuditTrail: true,
            requiresCompliancePolicy: true,
            shouldShipBeforeV1: false,
            boundaryRule: "Do not add team setup, admin screens, or compliance work to the personal V1 app."
        )
    }
}
