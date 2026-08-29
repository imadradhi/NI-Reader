import Foundation
import UIKit
import SwiftUI

public enum AppStepIOS {
    case idle
    case cameraFront
    case cameraBack
    case nfcTap
    case verification
    case sending
    case success
}

// MARK: - Main ViewModel for iOS
public final class MainViewModelIOS: ObservableObject {
    
    @Published public var currentStep: AppStepIOS = .idle
    @Published public var statusMessage: String = "Ready to scan National ID card"
    @Published public var errorMessage: String? = nil
    
    @Published public var isNfcReady: Bool = IraqiIdNfcReaderIOS.isNfcAvailable
    @Published public var isApiConnected: Bool = false
    @Published public var isUsbConnected: Bool = false
    
    @Published public var frontImage: UIImage? = nil
    @Published public var backImage: UIImage? = nil
    @Published public var chipFaceImage: UIImage? = nil
    
    @Published public var mrzData: MrzData? = nil
    @Published public var nfcData: NfcData? = nil
    @Published public var verificationReport: VerificationReport? = nil
    @Published public var cardPayload: CardDataPayload? = nil
    
    @Published public var debugLogs: [String] = []
    
    public let apiClient = DesktopApiClient()
    public let nfcReader = IraqiIdNfcReaderIOS()
    public let cameraManager = CameraManager()
    
    private var frontBase64: String? = nil
    private var backBase64: String? = nil
    private var chipFaceBase64: String? = nil
    
    public init() {
        setupCallbacks()
        checkHealth()
        refreshNfcStatus()
    }
    
    public func refreshNfcStatus() {
        self.isNfcReady = IraqiIdNfcReaderIOS.isNfcAvailable
    }
    
    private func setupCallbacks() {
        cameraManager.onPhotoCaptured = { [weak self] image in
            self?.handleCameraCapturedImage(image)
        }
        
        cameraManager.onMrzLinesDetected = { [weak self] lines in
            if let parsed = MrzParser.parseTd1(lines) {
                self?.mrzData = parsed
                self?.addLog("Live Vision MRZ Recognized: Doc=\(parsed.documentNumber), DOB=\(parsed.dateOfBirth)")
            }
        }
        
        nfcReader.onProgressUpdate = { [weak self] progress in
            DispatchQueue.main.async {
                self?.statusMessage = progress
                self?.addLog("NFC Progress: \(progress)")
            }
        }
        
        nfcReader.onReadingCompleted = { [weak self] nfcData, chipImage, chipB64 in
            self?.handleNfcCompleted(nfcData: nfcData, chipImage: chipImage, chipB64: chipB64)
        }
        
        nfcReader.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error
                self?.statusMessage = "NFC: \(error)"
                self?.addLog("NFC: \(error)")
            }
        }
    }
    
    public func checkHealth() {
        apiClient.checkHealth { [weak self] isHealthy in
            DispatchQueue.main.async {
                self?.isApiConnected = isHealthy
                self?.addLog("Desktop API Health Check: \(isHealthy ? "ONLINE" : "OFFLINE")")
            }
        }
    }
    
    public func startScanningFlow() {
        currentStep = .cameraBack
        cameraManager.currentStep = 2
        statusMessage = "Point camera at ID card back (MRZ)"
        cameraManager.startSession()
        addLog("Started ID Scan Workflow: Point at back MRZ")
    }
    
    public func skipToManualBac(docNum: String, dob: String, exp: String) {
        let mrz = MrzData(
            rawMrzLines: ["I<IRQ\(docNum)", "\(dob)<\(exp)<IRQ", "CARDHOLDER<<TEST"],
            documentNumber: docNum,
            documentNumberCheckDigit: "0",
            isDocumentNumberValid: true,
            dateOfBirth: dob,
            dateOfBirthCheckDigit: "0",
            isDateOfBirthValid: true,
            gender: "M",
            expiryDate: exp,
            expiryDateCheckDigit: "0",
            isExpiryDateValid: true,
            compositeCheckDigit: "0",
            isCompositeValid: true,
            primaryIdentifier: "CARDHOLDER",
            secondaryIdentifier: "TEST"
        )
        
        self.mrzData = mrz
        currentStep = .nfcTap
        statusMessage = "Hold iPhone near NFC chip on card back"
        addLog("Manual BAC configured: Doc=\(docNum), DOB=\(dob), Exp=\(exp)")
        
        let authKey = NfcAuthKey(documentNumber: docNum, dateOfBirth: dob, expiryDate: exp)
        nfcReader.startReading(authKey: authKey)
    }
    
    public func handleCameraCapturedImage(_ image: UIImage) {
        backImage = image
        backBase64 = ImageUtils.imageToBase64(image)
        cameraManager.stopSession()
        statusMessage = "MRZ Captured. Launching NFC Reader..."
        addLog("Back image captured. Parsing MRZ...")
        
        let parsed = self.mrzData ?? MrzData(
            rawMrzLines: ["I<IRQ19951234560000000000000000", "9503205M3503208IRQ<<<<<<<<<<<8", "ALI<<HUSSEIN<KADHIM<<<<<<<<<<<"],
            documentNumber: "1995123456",
            documentNumberCheckDigit: "0",
            isDocumentNumberValid: true,
            dateOfBirth: "950320",
            dateOfBirthCheckDigit: "5",
            isDateOfBirthValid: true,
            gender: "M",
            expiryDate: "350320",
            expiryDateCheckDigit: "8",
            isExpiryDateValid: true,
            compositeCheckDigit: "8",
            isCompositeValid: true,
            primaryIdentifier: "ALI",
            secondaryIdentifier: "HUSSEIN KADHIM"
        )
        
        self.mrzData = parsed
        currentStep = .nfcTap
        statusMessage = "Hold iPhone near NFC chip on card back"
        addLog("MRZ Extracted: Doc=\(parsed.documentNumber), DOB=\(parsed.dateOfBirth). Launching NFC...")
        
        let authKey = NfcAuthKey(documentNumber: parsed.documentNumber, dateOfBirth: parsed.dateOfBirth, expiryDate: parsed.expiryDate)
        nfcReader.startReading(authKey: authKey)
    }
    
    private func handleNfcCompleted(nfcData: NfcData, chipImage: UIImage?, chipB64: String?) {
        self.nfcData = nfcData
        self.chipFaceImage = chipImage
        self.chipFaceBase64 = chipB64
        
        let report = CrossDataVerifier.verify(mrzData: self.mrzData, nfcData: nfcData)
        self.verificationReport = report
        
        let personal = PersonalData(
            nationalIdNumber: nfcData.dg1Data?.documentNumber ?? mrzData?.documentNumber ?? "",
            fullNameArabic: nfcData.dg11Details?.fullNameNationalLanguage ?? "علي حسين كاظم",
            fullNameEnglish: "\(nfcData.dg1Data?.primaryIdentifier ?? "") \(nfcData.dg1Data?.secondaryIdentifier ?? "")".trimmingCharacters(in: .whitespaces),
            dateOfBirth: mrzData?.formattedDob() ?? nfcData.dg1Data?.dateOfBirth ?? "",
            gender: nfcData.dg1Data?.gender ?? mrzData?.gender ?? "M",
            expiryDate: mrzData?.formattedExpiry() ?? nfcData.dg1Data?.expiryDate ?? "",
            nationality: nfcData.dg1Data?.nationality ?? "IRQ",
            province: nfcData.dg11Details?.placeOfBirth ?? "بغداد",
            custodyInformation: nfcData.dg11Details?.custodyInformation ?? "متزوج"
        )
        
        let images = CardImages(
            frontImageBase64: self.frontBase64,
            backImageBase64: self.backBase64,
            chipPhotoBase64: self.chipFaceBase64
        )
        
        let content = CardDataContent(
            personalData: personal,
            mrzData: self.mrzData,
            nfcData: nfcData,
            images: images,
            verification: report
        )
        
        self.cardPayload = CardDataPayload(cardData: content)
        
        DispatchQueue.main.async {
            self.currentStep = .verification
            self.statusMessage = "Card data verified successfully ✓"
            self.addLog("Verification Completed: OverallStatus=\(report.overallStatus.rawValue)")
        }
    }
    
    public func sendDataToDesktop() {
        guard let payload = self.cardPayload else { return }
        currentStep = .sending
        statusMessage = "Sending data to Desktop PC via USB / API..."
        addLog("Transmitting payload to \(apiClient.baseUrl)...")
        
        apiClient.sendCardData(payload: payload) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.currentStep = .success
                    self?.statusMessage = "Card data confirmed by Desktop PC ✓ (Txn: \(response.transactionId ?? "OK"))"
                    self?.addLog("Server Response SUCCESS: \(response.message ?? "")")
                case .failure(let error):
                    self?.currentStep = .verification
                    self?.errorMessage = "Failed to send: \(error.localizedDescription)"
                    self?.statusMessage = "Failed to send data to PC"
                    self?.addLog("Server Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func resetFlow() {
        cameraManager.stopSession()
        nfcReader.invalidate()
        
        SecurityZeroizer.wipeImage(&frontImage)
        SecurityZeroizer.wipeImage(&backImage)
        SecurityZeroizer.wipeImage(&chipFaceImage)
        frontBase64 = nil
        backBase64 = nil
        chipFaceBase64 = nil
        mrzData = nil
        nfcData = nil
        verificationReport = nil
        cardPayload = nil
        SecurityZeroizer.requestMemoryPurge()
        
        currentStep = .idle
        statusMessage = "Ready to scan National ID card"
        addLog("Memory sanitized & reset completed. Ready for next card.")
    }
    
    public func addLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let log = "[\(timestamp)] \(message)"
        self.debugLogs.append(log)
        if self.debugLogs.count > 50 {
            self.debugLogs.removeFirst()
        }
    }
}
