//
//  ContentView.swift
//  App
//
//  Created by user on 8/11/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            NavigationLink("Speech recognition") {
                SpeechView()
            }
            NavigationLink("Vision recognition") {
                ScannerView()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
