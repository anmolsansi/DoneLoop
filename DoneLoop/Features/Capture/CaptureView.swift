import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var services: AppServices
    @StateObject private var voiceCapture = VoiceCaptureController()
    @State private var typedCapture = ""
    @State private var isShowingClearConfirmation = false
    @State private var isShowingInterpretation = false
    @State private var lastSavedCaptureID: UUID?
    @State private var parserOutput: DLParserOutput?
    @State private var parseErrorMessage: String?
    @State private var isParsingCapture = false

    let showTaskDetail: () -> Void
    let showDecisionSheet: () -> Void
    let showToday: () -> Void
    let showInbox: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DLSpacing.xl) {
                VStack(spacing: DLSpacing.md) {
                    Button(action: toggleVoiceCapture) {
                        Image(systemName: voiceCapture.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 112, height: 112)
                            .background(voiceCapture.isRecording ? DLColor.danger : DLColor.primary, in: Circle())
                    }
                    .accessibilityLabel(voiceCapture.isRecording ? "Stop voice capture" : "Start voice capture")

                    Text("Capture something before it slips.")
                        .font(.headline)
                        .foregroundStyle(DLColor.textPrimary)

                    Text(voiceCapture.state.statusText)
                        .font(.caption)
                        .foregroundStyle(DLColor.textSecondary)

                    Text(services.parserModeLabel)
                        .font(.caption2)
                        .foregroundStyle(DLColor.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DLSpacing.xl)

                VStack(alignment: .leading, spacing: DLSpacing.sm) {
                    HStack {
                        Text("Voice Transcript")
                            .font(.headline)
                        Spacer()
                        if !voiceCapture.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Retry", action: voiceCapture.retry)
                                .font(.caption.weight(.semibold))
                        }
                    }

                    TextEditor(text: $voiceCapture.transcript)
                        .frame(minHeight: 96)
                        .padding(DLSpacing.sm)
                        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DLRadius.md)
                                .stroke(DLColor.divider, lineWidth: 0.5)
                        )

                    HStack {
                        Button("Cancel", action: voiceCapture.cancel)
                            .disabled(voiceCapture.transcript.isEmpty && !voiceCapture.isRecording)
                        Spacer()
                        DLPrimaryButton("Save Voice", systemImage: "waveform") {
                            saveAndParseCapture(text: voiceCapture.transcript, source: .voice)
                            voiceCapture.stop()
                        }
                        .disabled(voiceCapture.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                VStack(alignment: .leading, spacing: DLSpacing.sm) {
                    Text("Text Capture")
                        .font(.headline)
                    TextEditor(text: $typedCapture)
                        .frame(minHeight: 120)
                        .padding(DLSpacing.sm)
                        .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DLRadius.md)
                                .stroke(DLColor.divider, lineWidth: 0.5)
                        )

                    HStack {
                        Button("Clear") {
                            isShowingClearConfirmation = true
                        }
                        .disabled(typedCapture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        DLPrimaryButton("Save / Interpret", systemImage: "wand.and.stars") {
                            saveAndParseCapture(text: typedCapture, source: .text)
                        }
                        .disabled(typedCapture.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                VStack(alignment: .leading, spacing: DLSpacing.md) {
                    HStack {
                        Text("Recent Captures")
                            .font(.headline)
                        Spacer()
                        Button("Decision Sheet", action: showDecisionSheet)
                            .font(.caption.weight(.semibold))
                    }

                    if services.localStore.recentCaptures.isEmpty {
                        DLEmptyState(
                            title: "No captures yet",
                            detail: "Voice and text captures will appear here after you save them.",
                            systemImage: "tray"
                        )
                    } else {
                        ForEach(services.localStore.recentCaptures) { capture in
                            NavigationLink {
                                if let storedCapture = services.localStore.capture(id: capture.id) {
                                    CaptureDetailView(capture: storedCapture)
                                } else {
                                    DLEmptyState(
                                        title: "Capture missing",
                                        detail: "This capture is no longer available.",
                                        systemImage: "exclamationmark.triangle"
                                    )
                                }
                            } label: {
                            HStack(spacing: DLSpacing.md) {
                                Image(systemName: capture.source == "Voice" ? "mic" : "text.cursor")
                                    .foregroundStyle(DLColor.primary)
                                VStack(alignment: .leading, spacing: DLSpacing.xs) {
                                    Text(capture.title)
                                        .font(.headline)
                                        .foregroundStyle(DLColor.textPrimary)
                                    Text("\(capture.status) - \(capture.timestamp)")
                                        .font(.callout)
                                        .foregroundStyle(DLColor.textSecondary)
                                    Text(capture.detail)
                                        .font(.caption)
                                        .foregroundStyle(DLColor.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DLColor.textTertiary)
                            }
                            .padding(DLSpacing.md)
                            .background(DLColor.surface, in: RoundedRectangle(cornerRadius: DLRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DLRadius.md)
                                    .stroke(DLColor.divider, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DLSpacing.lg)
        }
        .background(DLColor.background)
        .navigationTitle("Capture")
        .confirmationDialog("Clear typed capture?", isPresented: $isShowingClearConfirmation, titleVisibility: .visible) {
            Button("Clear Text", role: .destructive) {
                typedCapture = ""
            }
        }
        .sheet(isPresented: $isShowingInterpretation) {
            InterpretationPreviewView(
                output: parserOutput,
                errorMessage: parseErrorMessage,
                isParsing: isParsingCapture,
                retry: retryLastCapture,
                showTaskDetail: showTaskDetail,
                showToday: showToday,
                showInbox: showInbox
            )
                .presentationDetents([.large])
        }
    }

    private func toggleVoiceCapture() {
        if voiceCapture.isRecording {
            voiceCapture.stop()
        } else {
            voiceCapture.start()
        }
    }

    private func saveAndParseCapture(text: String, source: DLCaptureSource) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let capture = services.localStore.createCapture(
            rawText: trimmed,
            source: source,
            transcript: source == .voice ? trimmed : nil,
            processingStatus: .readyToInterpret
        )
        lastSavedCaptureID = capture.id

        if source == .text {
            typedCapture = ""
        }

        isShowingInterpretation = true
        parseCapture(capture)
    }

    private func retryLastCapture() {
        guard let lastSavedCaptureID, let capture = services.localStore.capture(id: lastSavedCaptureID) else { return }
        parseCapture(capture)
    }

    private func parseCapture(_ capture: DLCapture) {
        parserOutput = nil
        parseErrorMessage = nil
        isParsingCapture = true

        Task {
            let result = await services.aiRouter.parseCommand(
                DLAIRequest(
                    input: capture.transcript ?? capture.rawText,
                    sourceCaptureID: capture.id,
                    timeZoneIdentifier: services.localStore.settings.timezoneIdentifier
                ),
                settings: services.localStore.settings
            )

            await MainActor.run {
                isParsingCapture = false

                switch result {
                case .success(let output):
                    parserOutput = output
                    persistParserOutput(output, for: capture)
                case .failure(let error):
                    parseErrorMessage = error.localizedDescription
                    var failedCapture = capture
                    failedCapture.processingStatus = .failed
                    services.localStore.upsertCapture(failedCapture)
                }
            }
        }
    }

    private func persistParserOutput(_ output: DLParserOutput, for capture: DLCapture) {
        var updatedCapture = capture
        updatedCapture.processingStatus = DLParserOutputValidator.validate(output).canSave ? .readyToInterpret : .needsReview
        updatedCapture.confidenceScore = output.confidence

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(output) {
            updatedCapture.aiOutputJSON = String(data: data, encoding: .utf8)
        }

        services.localStore.upsertCapture(updatedCapture)
    }
}
