// SpeechViewModel.swift

import AVFAudio
import FoundationModels
import SwiftUI

@Observable
class SpeechViewModel {
    var finalizedTranscript: String = ""
    var volatileTranscript: String = ""
    var generatedJSON: String = ""
    var isExtracting: Bool = false
    var errorMessage: String = ""
    var listening: Bool = false

    private var recogniser = SpeechRecogniser()
    private var financeService = FinanceService()
    
    private var recordingStart: Date?

    init() {
        recogniser.setup()
    }

    func startRecording() {
        errorMessage = ""
        generatedJSON = ""
        finalizedTranscript = ""
        volatileTranscript = ""
        recordingStart = Date()
        recogniser.start()
        listening = true

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if !self.recogniser.listening {
                self.listening = false
                timer.invalidate()
                return
            }
            self.volatileTranscript = self.recogniser.text
        }
    }

    func stopRecordingAndExtract() {
        recogniser.stop()
        listening = false
        guard let start = recordingStart else {
            errorMessage = "Missing recording start time."
            return
        }
        let transcript = finalizedTranscript.isEmpty ? recogniser.text : finalizedTranscript

        Task {
            await extractFinanceEvent(from: transcript, recordingStart: start)
        }
    }

    private func extractFinanceEvent(from transcript: String, recordingStart: Date) async {
        isExtracting = true
        defer { isExtracting = false }
        errorMessage = ""

        do {
            let event = try await financeService.extract(from: transcript, recordingStart: recordingStart)
            generatedJSON = try prettyJSON(from: event)
        } catch {
            errorMessage = "Extraction failed: \(error.localizedDescription)"
        }
    }
    
    private func prettyJSON<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try String(data: encoder.encode(value), encoding: .utf8) ?? "{}"
    }
}

