//
//  Processor.swift
//  Learn
//
//  Created by user on 6/11/25.
//

import UIKit
@preconcurrency import Vision
import VisionKit

@Observable
class Processor {
    var isProcessing = false
    var extracted = ""
    var error: Error?

    func process(_ image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(
                    throwing: NSError(
                        domain: "DocumentProcessor", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"]))
                return
            }
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "DocumentProcessor", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "No text found"]))
                    return
                }
                let strings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                let text = strings.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-UK"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
