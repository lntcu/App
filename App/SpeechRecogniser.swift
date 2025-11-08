//
//  SpeechRecogniser.swift
//  Language
//
//  Created by user on 6/11/25.
//

import Foundation
import AVFoundation
import Speech

@Observable
class SpeechRecogniser {
    var text: String = "No speech recognized"
    var listening: Bool = false
    var engine: AVAudioEngine!
    var speechRecognizer: SFSpeechRecognizer!
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest!
    var recognitionTask: SFSpeechRecognitionTask!
    
    init() {
        setup()
    }
    
    func setup() {
        engine = AVAudioEngine()
        speechRecognizer = SFSpeechRecognizer()
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized")
                @unknown default:
                    fatalError("Unknown authorization status")
                }
            }
        }
    }
    
    func start() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        listening = true
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest.append(buffer)
        }
        engine.prepare()
        try! engine.start()
        speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                Task {
                    self.text = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                self.engine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    }
    
    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        recognitionRequest.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        listening = false
    }
}
