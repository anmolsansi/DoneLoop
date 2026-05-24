import AVFoundation
import Speech
import SwiftUI

@MainActor
final class VoiceCaptureController: ObservableObject {
    enum CaptureState: Equatable {
        case idle
        case requestingPermission
        case recording
        case denied(String)
        case failed(String)

        var statusText: String {
            switch self {
            case .idle: "Ready"
            case .requestingPermission: "Requesting permission"
            case .recording: "Listening"
            case .denied(let message), .failed(let message): message
            }
        }
    }

    @Published private(set) var state: CaptureState = .idle
    @Published var transcript = ""

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledInputTap = false

    var isRecording: Bool {
        state == .recording
    }

    func start() {
        guard !isRecording else { return }

        if shouldUseSimulatorVoiceFallback {
            state = .failed("Voice input is not available in this simulator.")
            return
        }

        state = .requestingPermission

        Task {
            let hasPermissions = await requestPermissions()
            guard hasPermissions else { return }
            beginRecording()
        }
    }

    func stop() {
        audioEngine.stop()
        removeInputTapIfNeeded()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        state = .idle
    }

    func cancel() {
        stop()
        transcript = ""
    }

    func retry() {
        cancel()
        start()
    }

    private func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            state = .denied("Speech recognition permission is needed for voice capture.")
            return false
        }

        #if os(iOS)
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard microphoneGranted else {
            state = .denied("Microphone permission is needed for voice capture.")
            return false
        }
        #endif

        return true
    }

    private func beginRecording() {
        guard speechRecognizer?.isAvailable == true else {
            state = .failed("Speech recognition is not available right now.")
            return
        }

        if shouldUseSimulatorVoiceFallback {
            recognitionRequest = nil
            state = .failed("Voice input is not available in this simulator.")
            return
        }

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
        } catch {
            state = .failed("Voice capture could not start.")
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        removeInputTapIfNeeded()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            recognitionRequest = nil
            state = .failed("Voice input is not available.")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        hasInstalledInputTap = true

        audioEngine.prepare()

        do {
            try audioEngine.start()
            state = .recording
        } catch {
            removeInputTapIfNeeded()
            recognitionRequest = nil
            state = .failed("Voice capture could not start.")
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if error != nil {
                    self.stop()
                    self.state = self.transcript.isEmpty ? .failed("No speech was detected.") : .idle
                }
            }
        }

        if recognitionTask == nil {
            audioEngine.stop()
            removeInputTapIfNeeded()
            recognitionRequest = nil
            state = .failed("Speech recognition could not start.")
        }
    }

    private func removeInputTapIfNeeded() {
        guard hasInstalledInputTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasInstalledInputTap = false
    }

    private var shouldUseSimulatorVoiceFallback: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
