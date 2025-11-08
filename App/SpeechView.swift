// ContentView.swift

import SwiftUI
import AVFAudio
import FoundationModels

struct SpeechView: View {
    @State private var recogniser = SpeechRecogniser()
    @State private var model = SystemLanguageModel(useCase: .contentTagging) // better for extraction
    @State private var session = LanguageModelSession()
    
    @State private var recordingStart: Date?
    @State private var finalizedTranscript: String = ""
    @State private var volatileTranscript: String = ""
    
    @State private var generatedJSON: String = ""
    @State private var lastEvent: FinanceEvent?
    @State private var isExtracting: Bool = false
    @State private var errorMessage: String = ""

    // Structured schema for extraction
    @Generable
    struct FinanceEvent: Equatable, Codable {
        @Guide(.anyOf(["expense", "income", "transfer"]))
        let type: String

        @Guide(description: "High-level category like food, transport, bills, shopping, entertainment, healthcare, education, travel, other")
        let category: String

        @Guide(description: "Total amount, positive number")
        let amount: Double

        @Guide(description: "ISO currency code or symbol inferred from text, e.g., USD, IDR, $, Rp")
        let currency: String

        @Guide(description: "Merchant or source name if present")
        let merchant: String

        @Guide(description: "Primary event date from recording time (ISO-8601). If utterance specifies another date/time explicitly, put that in dateMentioned and leave date as recording time.")
        let date: String

        @Guide(description: "Optional explicit date mentioned in speech, ISO-8601 if resolvable; otherwise empty string.")
        let dateMentioned: String
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Live transcript view (volatile + finalized)
            ScrollView {
                Text(displayTranscript)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)

            HStack {
                Button(recogniser.listening ? "Stop Recording" : "Start Recording",
                       systemImage: recogniser.listening ? "microphone.slash" : "microphone") {
                    if recogniser.engine.isRunning {
                        stopRecordingAndExtract()
                    } else {
                        startRecording()
                    }
                }
                .buttonStyle(.glass)
                .disabled(isExtracting)
                
                if isExtracting {
                    ProgressView("Extracting…")
                        .progressViewStyle(.circular)
                }
            }

            if !generatedJSON.isEmpty {
                Text("Generated JSON")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Show pretty JSON
                ScrollView {
                    Text(generatedJSON)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .onAppear {
            recogniser.setup()
            configureSession()
        }
        .glassEffect()
    }
    
    private var displayTranscript: String {
        if volatileTranscript.isEmpty {
            return finalizedTranscript
        } else {
            return finalizedTranscript + " " + volatileTranscript
        }
    }
    
    // Configure the Foundation Models session with instructions tuned for extraction.
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
                - date: use the recording time provided in the prompt, ISO-8601 string.
                - dateMentioned: if the utterance explicitly says a different absolute date/time (e.g., "on Nov 2", "yesterday at 7 pm"), resolve to ISO-8601 if possible; otherwise empty string.
                """
            }
        )
    }
    
    private func startRecording() {
        errorMessage = ""
        generatedJSON = ""
        finalizedTranscript = ""
        volatileTranscript = ""
        recordingStart = Date()
        recogniser.start()
        // If SpeechRecogniser doesn't provide callbacks, mirror live text periodically.
        // This avoids passing arguments to a start() method that takes none.
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            // Stop updating when recogniser stops listening.
            if !recogniser.listening { timer.invalidate(); return }
            // Update volatile transcript from recogniser's current text buffer.
            let current = recogniser.text
            // If recogniser exposes finalized segments separately in your implementation,
            // you can adjust this logic; here we simply treat all as volatile until stop.
            volatileTranscript = current
        }
    }
    
    private func stopRecordingAndExtract() {
        recogniser.stop()
        // Ensure we have a recording start and some text
        guard let start = recordingStart else {
            errorMessage = "Missing recording start time."
            return
        }
        let transcript = finalizedTranscript.isEmpty ? recogniser.text : finalizedTranscript
        
        Task {
            await extractFinanceEvent(from: transcript, recordingStart: start)
        }
    }
    
    // Call Foundation Models with schema-guided generation and produce JSON.
    private func extractFinanceEvent(from transcript: String, recordingStart: Date) async {
        isExtracting = true
        defer { isExtracting = false }
        errorMessage = ""
        
        // Build a prompt that includes the transcript and the recording-start ISO timestamp
        let isoDate = iso8601String(from: recordingStart)
        let prompt = Prompt {
            """
            Transcript:
            \(transcript)

            RecordingStartISO: \(isoDate)

            Task:
            - Use RecordingStartISO as FinanceEvent.date.
            - Only populate dateMentioned if an explicit absolute date/time is spoken.
            - Do not add extra fields; adhere to FinanceEvent schema strictly.
            """
        }
        
        do {
            let result = try await session.respond(
                to: prompt,
                generating: FinanceEvent.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(
                    sampling: .greedy,       // deterministic, good for numbers/categories
                    temperature: 0.1,        // low creativity; reduce drift
                    maximumResponseTokens: 256
                )
            )
            let event = result.content
            lastEvent = event
            generatedJSON = try prettyJSON(from: event)
        } catch {
            errorMessage = "Extraction failed: \(error)"
        }
    }
    
    // Helpers
    
    private func iso8601String(from date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: date)
    }
    
    private func prettyJSON<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(data: try encoder.encode(value), encoding: .utf8) ?? "{}"
    }
}


#Preview {
    SpeechView()
}
