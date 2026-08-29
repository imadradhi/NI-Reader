import Foundation
import AVFoundation
import UIKit
import Vision

// MARK: - iOS Camera & Real-Time Apple Vision Auto-Capture Manager
public final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    @Published public var isCardLocked: Bool = false
    @Published public var autoCapturePrompt: String = "Align card within frame"
    
    public var onPhotoCaptured: ((UIImage) -> Void)?
    public var currentStep: Int = 1 // 1: Front, 2: Back (MRZ)
    
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.iraq.nireader.camera.session")
    private let visionQueue = DispatchQueue(label: "com.iraq.nireader.camera.vision")
    
    private var isCapturing = false
    private var consecutiveDetectionCount = 0
    private var lastAutoCaptureTime: TimeInterval = 0
    
    public override init() {
        super.init()
        setupSession()
    }
    
    public func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }
            
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
            }
            
            self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.isCapturing = false
            self.consecutiveDetectionCount = 0
            self.captureSession.startRunning()
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }
    
    public func triggerManualCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Live Vision Analysis)
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isCapturing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let now = Date().timeIntervalSince1970
        guard now - lastAutoCaptureTime > 1.5 else { return }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self, error == nil else { return }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let detectedTexts = observations.compactMap { $0.topCandidates(1).first?.string }
            self.evaluateDetectedText(detectedTexts, now: now)
        }
        
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
    
    private func evaluateDetectedText(_ texts: [String], now: TimeInterval) {
        var isDetected = false
        
        if currentStep == 1 {
            // Front side detection: Keywords or structured blocks
            let fullText = texts.joined(separator: " ").uppercased()
            let hasKeywords = fullText.contains("IRAQ") || fullText.contains("REPUBLIC") || fullText.contains("CARD") ||
                              fullText.contains("بطاقة") || fullText.contains("وطنية") || texts.count >= 3
            if hasKeywords {
                isDetected = true
            }
        } else if currentStep == 2 {
            // Back side MRZ detection: 3-line TD1 cues
            let candidateLines = texts.map { MrzParser.sanitizeLine($0) }
                .filter { $0.count in 25...35 && ($0.contains("<") || $0.starts(with: "I") || $0.contains("IRQ")) }
            
            if candidateLines.count >= 2 {
                isDetected = true
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isDetected {
                self.consecutiveDetectionCount += 1
                self.isCardLocked = true
                self.autoCapturePrompt = self.currentStep == 1 ? "Front Card Locked ✓" : "MRZ Locked ✓"
                
                if self.consecutiveDetectionCount >= 2 && !self.isCapturing {
                    self.isCapturing = true
                    self.lastAutoCaptureTime = now
                    self.triggerHaptic()
                    self.triggerManualCapture()
                }
            } else {
                self.consecutiveDetectionCount = 0
                self.isCardLocked = false
                self.autoCapturePrompt = self.currentStep == 1 ? "Place front side inside frame" : "Point camera at back side (MRZ)"
            }
        }
    }
    
    private func triggerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { isCapturing = false }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(image)
        }
    }
}
