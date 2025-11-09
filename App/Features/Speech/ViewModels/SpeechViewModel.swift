// SpeechViewModel.swift

import AVFAudio
import FoundationModels
import SwiftUI
import SwiftData

@Observable
class SpeechViewModel {
    var finalizedTranscript: String = ""
    var volatileTranscript: String = ""
    var statusMessage: String = ""
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
        statusMessage = ""
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

    func stopRecordingAndExtract(modelContext: ModelContext) {
        recogniser.stop()
        listening = false
        guard let start = recordingStart else {
            errorMessage = "Missing recording start time."
            return
        }
        let transcript = finalizedTranscript.isEmpty ? recogniser.text : finalizedTranscript

        Task {
            await extractFinanceEvent(from: transcript, recordingStart: start, modelContext: modelContext)
        }
    }

    private func extractFinanceEvent(from transcript: String, recordingStart: Date, modelContext: ModelContext) async {
        isExtracting = true
        defer { isExtracting = false }
        errorMessage = ""

        do {
            let eventDTO = try await financeService.extract(from: transcript, recordingStart: recordingStart)
            let event = FinanceEvent(from: eventDTO, recordingDate: recordingStart)
            modelContext.insert(event)
            try modelContext.save()
            statusMessage = "Successfully saved event."
        } catch {
            errorMessage = "Extraction failed: \(error.localizedDescription)"
        }
    }
}

