//
//  ScannerView.swift
//  App
//
//  Created by user on 8/11/25.
//

import SwiftUI
import VisionKit
import SwiftData

struct ScannerView: View {
    @State private var processor = Processor()
    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var processedImage: UIImage?
    @State private var extracted = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var step = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    if let image = processedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(24)
                            .padding()
                    }
                    if !isProcessing && processedImage == nil {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan", systemImage: "camera.fill")
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundStyle(.white)
                                .glassEffect(.clear.tint(.blue).interactive())
                        }
                        .padding(.horizontal)
                    }
                    if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .transition(.blurReplace.combined(with: .scale.combined(with: .opacity)))
                    }
                    if !extracted.isEmpty && !isProcessing {
                        VStack {
                            HStack {
                                Text("Text Extracted")
                                    .font(.headline)
                                Spacer()
                                Text("\(extracted.count) characters")
                                    .foregroundStyle(.secondary)
                            }
                            Text(extracted)
                        }
                        .padding(.horizontal)
                        .transition(.blurReplace.combined(with: .scale.combined(with: .opacity)))
                    }
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Scan receipet")
            .sheet(isPresented: $showScanner) {
                Camera(scannedImages: $scannedImages)
                    .ignoresSafeArea()
            }
            .onChange(of: scannedImages) { oldValue, newValue in
                if !newValue.isEmpty {
                    Task {
                        await process()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func process() async {
        guard let firstImage = scannedImages.first else { return }
        isProcessing = true
        step = "Processing scanned document..."
        extracted = ""
        processedImage = firstImage
        do {
            step = "Recognizing text..."
            extracted = try await processor.process(firstImage)
            if extracted.isEmpty {
                throw DocumentProcessorError.noTextFound
            }
            step = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            step = ""
        }
        isProcessing = false
    }
}

struct Camera: UIViewControllerRepresentable {
    @Binding var scannedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(scannedImages: $scannedImages, dismiss: dismiss)
    }
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        @Binding var scannedImages: [UIImage]
        let dismiss: DismissAction
        init(scannedImages: Binding<[UIImage]>, dismiss: DismissAction) {
            self._scannedImages = scannedImages
            self.dismiss = dismiss
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }
            scannedImages = images
            dismiss()
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanning failed: \(error.localizedDescription)")
            dismiss()
        }
    }
}

enum DocumentProcessorError: LocalizedError {
    case noTextFound
    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text was found in the image. Please try a different image with clearer text."
        }
    }
}
