// FinanceService.swift

import Foundation
import FoundationModels
import SwiftUI

@Observable
class FinanceService {
    private let model = SystemLanguageModel(useCase: .contentTagging)
    private var session: LanguageModelSession?

    init() {
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

    func extract(from transcript: String, recordingStart: Date) async throws -> FinanceEvent {
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

        guard let session = session else {
            throw NSError(domain: "FinanceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "LanguageModelSession not configured."])
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
        
        var event = result.content
        event.date = isoDate
        return event
    }

    private func iso8601String(from date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: date)
    }
}
