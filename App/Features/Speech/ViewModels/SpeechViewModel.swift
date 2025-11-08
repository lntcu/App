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
            // Core expenses
            "food_and_drink",
            "groceries",
            "transport",
            "ride_hailing",
            "fuel",
            "parking",
            "tolls",
            "utilities",
            "electricity",
            "water",
            "gas",
            "internet",
            "mobile_plan",
            "rent",
            "mortgage",
            "home_maintenance",
            "insurance",

            // Financial services
            "bank_fees",
            "atm_fees",
            "interest",
            "loan_payment",
            "taxes",

            // Daily spending
            "shopping",
            "convenience",
            "personal_care",
            "household_supplies",

            // Lifestyle
            "entertainment",
            "subscriptions",
            "gaming",
            "sports_and_fitness",

            // Food services
            "restaurants",
            "cafes",
            "delivery_fees",

            // Health & education
            "healthcare",
            "medicine",
            "medical_fees",
            "education",
            "tuition",
            "books_and_supplies",

            // Travel
            "travel",
            "accommodation",
            "airfare",
            "train_bus",
            "visa_and_fees",

            // Children & family
            "childcare",
            "family_support",

            // Giving
            "charity",
            "zakat_infaq_sedekah",

            // Digital wallets & top-ups (ID specific)
            "e_wallet_topup",
            "pulsa_topup",
            "data_package",

            // Work & biz
            "work_expense",
            "office_supplies",
            "software",

            // Income categories (for type=income)
            "salary",
            "bonus",
            "freelance",
            "refund",
            "cashback",
            "investment_income",

            // Transfers
            "transfer",
            "internal_transfer",

            // Catch-all
            "other"
        ]))
        let category: String

        @Guide(description: "Total amount, positive number")
        let amount: Double

        @Guide(description: "ISO currency code or symbol inferred from text, e.g., USD, IDR, $, Rp")
        let currency: String

        @Guide(description: "Merchant or source name if present")
        let merchant: String

        @Guide(description: "Primary event date from recording time (ISO-8601). If utterance specifies another date/time explicitly, put that in dateMentioned and leave date as recording time.")
        let date: String
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
                - type must be one of: expense, income, transfer.
                - Infer category from merchant or phrasing; default to "other" if unsure.
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

