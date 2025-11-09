// SpeechView.swift

import SwiftUI

struct SpeechView: View {
    @State private var viewModel = SpeechViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 12) {
            // Live transcript view (volatile + finalized)
            ScrollView {
                Text(displayTranscript)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)

            HStack {
                Button(viewModel.listening ? "Stop Recording" : "Start Recording",
                       systemImage: viewModel.listening ? "microphone.slash" : "microphone") {
                    if viewModel.listening {
                        viewModel.stopRecordingAndExtract(modelContext: modelContext)
                    } else {
                        viewModel.startRecording()
                    }
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isExtracting)
                
                if viewModel.isExtracting {
                    ProgressView("Extracting…")
                        .progressViewStyle(.circular)
                }
            }

            if !viewModel.statusMessage.isEmpty {
                Text("Status")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Show pretty JSON
                ScrollView {
                    Text(viewModel.statusMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
            }

            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .glassEffect()
    }
    
    private var displayTranscript: String {
        if viewModel.volatileTranscript.isEmpty {
            return viewModel.finalizedTranscript
        } else {
            return viewModel.finalizedTranscript + " " + viewModel.volatileTranscript
        }
    }
}

#Preview {
    SpeechView()
}
