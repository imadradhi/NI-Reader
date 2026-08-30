import Foundation
import AVFoundation
import UIKit
import Vision
import CoreMedia
import ImageIO

// MARK: - iOS Camera & Real-Time Apple Vision Auto-Capture Manager
public final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    @Published public var isCardLocked: Bool = false
    @Published public var autoCapturePrompt: String = "Align card within frame"
    
    public var onPhotoCaptured: ((UIImage) -> Void)?
    public var onMrzLinesDetected: (([String]) -> Void)?
    public var currentStep: Int = 2 // Back side (MRZ) default
    
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
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.customWords = ["IDIRQ", "IRQ", "EMAD"]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation.right, options: [:])
        try? handler.perform([request])
    }
    
    private func evaluateDetectedText(_ texts: [String], now: TimeInterval) {
        // Try parsing directly with mathematical check digit validation
        if let parsed = MrzParser.parseTd1(texts) {
            // STRICT GATE: Only lock and capture if all 3 check digits are mathematically valid!
            let isValid = parsed.isDocumentNumberValid && parsed.isDateOfBirthValid && parsed.isExpiryDateValid
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if isValid {
                    self.consecutiveDetectionCount += 1
                    self.isCardLocked = true
                    self.autoCapturePrompt = "MRZ Verified ✓ Capturing..."
                    
                    if self.consecutiveDetectionCount >= 1 && !self.isCapturing {
                        self.isCapturing = true
                        self.lastAutoCaptureTime = now
                        self.triggerHaptic()
                        self.onMrzLinesDetected?(parsed.rawMrzLines)
                        self.triggerManualCapture()
                    }
                } else {
                    // Check digits failed (blurry or incomplete frame) - do NOT accept garbage!
                    self.isCardLocked = false
                    self.autoCapturePrompt = "Hold steady... reading MRZ"
                }
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.consecutiveDetectionCount = 0
            self.isCardLocked = false
            self.autoCapturePrompt = "Point camera at ID card back (MRZ)"
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
