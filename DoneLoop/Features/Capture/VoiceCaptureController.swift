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

    var isRecording: Bool {
        state == .recording
    }

    func start() {
        guard !isRecording else { return }
        state = .requestingPermission

        Task {
            let hasPermissions = await requestPermissions()
            guard hasPermissions else { return }
            beginRecording()
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
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
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()

        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            try audioEngine.start()
            state = .recording
        } catch {
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
    }
}
