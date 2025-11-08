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
    private let model = SystemLanguageModel(useCase: .contentTagging)
    private var session: LanguageModelSession?

    private var recordingStart: Date?
    private var lastEvent: FinanceEvent?

    // Structured schema for extraction
    @Generable
    struct FinanceEvent: Equatable, Codable {
        @Guide(.anyOf(["expense", "income", "transfer"]))
        let type: String

        @Guide(.anyOf([
            "Food & Drink",
            "Transport",
            "Shopping",
            "Bills & Utilities",
            "Entertainment",
            "Health",
            "Income",
            "Transfer",
            "Other"
        ]))
        let category: String

        @Guide(description: "The specific item purchased, if mentioned (e.g., 'Big Mac', 'coffee'). Omit if not mentioned.")
        let item: String?

        @Guide(description: "Total amount, positive number. Omit if not mentioned.")
        let amount: Double?

        @Guide(description: "ISO currency code or symbol. Omit if not mentioned.")
        let currency: String?

        @Guide(description: "Merchant or source name. Omit if not mentioned.")
        let merchant: String?

        @Guide(description: "Primary event date from recording time (ISO-8601). If utterance specifies another date/time explicitly, put that in dateMentioned and leave date as recording time.")
        let date: String?
    }

    init() {
        recogniser.setup()
        configureSession()
    }

    private func configureSession() {
        session = LanguageModelSession(
            model: model,
            instructions: {
                """
                You extract structured finance events from the transcript.

                Rules:
                - Respond strictly using the FinanceEvent schema.
                - Extract the specific item purchased into the 'item' field if it is mentioned.
                - The 'category' must be one of: Food & Drink, Transport, Shopping, Bills & Utilities, Entertainment, Health, Income, Transfer, Other.
                - The 'type' must be one of: expense, income, transfer.
                - Infer category from merchant or phrasing; default to "Other" if unsure.
                - amount must be the numeric total; parse currencies and symbols (USD, IDR, $, Rp, etc).
                - merchant: name if present; avoid hallucination.
                - date: do not infer; the app will set this to the recording time after generation.
                """
            }
        )
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

        let isoDate = iso8601String(from: recordingStart)
        let prompt = Prompt {
            """
            Transcript:
            \(transcript)

            Task:
            - Do not infer date; the app will set FinanceEvent.date to the recording time.
            - Do not add extra fields; adhere to FinanceEvent schema strictly.
            """
        }

        do {
            guard let session = session else {
                errorMessage = "LanguageModelSession not configured."
                return
            }
            let result = try await session.respond(
                to: prompt,
                generating: FinanceEvent.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.1,
                    maximumResponseTokens: 256
                )
            )
            let event = result.content
            let fixedEvent = FinanceEvent(
                type: event.type,
                category: event.category,
                item: event.item,
                amount: event.amount,
                currency: event.currency,
                merchant: event.merchant,
                date: isoDate
            )
            lastEvent = fixedEvent
            generatedJSON = try prettyJSON(from: fixedEvent)
        } catch {
            errorMessage = "Extraction failed: \(error)"
        }
    }

    private func iso8601String(from date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: date)
    }

    private func prettyJSON<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try String(data: encoder.encode(value), encoding: .utf8) ?? "{}"
    }
}

