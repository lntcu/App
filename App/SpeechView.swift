//
//  ContentView.swift
//  Language
//
//  Created by user on 6/11/25.
//


import SwiftUI
import AVFAudio

struct SpeechView: View {
    @State private var recogniser = SpeechRecogniser()
    
    var body: some View {
        VStack {
            Text(recogniser.text)
            Button("Record", systemImage: recogniser.listening ? "microphone.slash" : "microphone") {
                if recogniser.engine.isRunning {
                    recogniser.stop()
                } else {
                    recogniser.start()
                }
            }
            .buttonStyle(.glass)
        }
        .onAppear {
            recogniser.setup()
        }
        .padding(5)
        .glassEffect()
    }
}

#Preview {
    SpeechView()
}
