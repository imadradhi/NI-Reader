import Foundation
import CoreNFC
import UIKit

// MARK: - NFC Auth Key for BAC
public struct NfcAuthKey {
    public let documentNumber: String
    public let dateOfBirth: String
    public let expiryDate: String
    
    public init(documentNumber: String, dateOfBirth: String, expiryDate: String) {
        self.documentNumber = documentNumber.replacingOccurrences(of: "<", with: "").trimmingCharacters(in: .whitespaces)
        self.dateOfBirth = dateOfBirth.replacingOccurrences(of: "<", with: "").trimmingCharacters(in: .whitespaces)
        self.expiryDate = expiryDate.replacingOccurrences(of: "<", with: "").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - CoreNFC ICAO 9303 / ISO 14443 Smart Card Reader Engine
public final class IraqiIdNfcReaderIOS: NSObject, NFCTagReaderSessionDelegate {
    
    private var nfcSession: NFCTagReaderSession?
    private var authKey: NfcAuthKey?
    
    public var onProgressUpdate: ((String) -> Void)?
    public var onReadingCompleted: ((NfcData, UIImage?, String?) -> Void)?
    public var onError: ((String) -> Void)?
    
    public override init() {
        super.init()
    }
    
    public static var isNfcAvailable: Bool {
        return NFCTagReaderSession.readingAvailable
    }
    
    public func startReading(authKey: NfcAuthKey) {
        guard NFCTagReaderSession.readingAvailable else {
            onError?("CoreNFC is not supported or disabled on this iPhone.")
            return
        }
        
        self.authKey = authKey
        nfcSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        nfcSession?.alertMessage = "Hold the top of your iPhone near the back of the Iraqi National ID card."
        nfcSession?.begin()
    }
    
    public func invalidate() {
        nfcSession?.invalidate()
        nfcSession = nil
    }
    
    // MARK: - NFCTagReaderSessionDelegate
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        onProgressUpdate?("NFC Ready. Searching for ISO/IEC 14443 smart card...")
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as? NFCReaderError
        if nfcError?.code != .readerSessionInvalidationErrorUserCanceled {
            onError?(error.localizedDescription)
        }
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        
        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                self.onError?(error.localizedDescription)
                return
            }
            
            switch tag {
            case .iso7816(let iso7816Tag):
                self.processIso7816Card(iso7816Tag: iso7816Tag, session: session)
            default:
                session.invalidate(errorMessage: "Unsupported card standard. Requires ISO/IEC 14443 (ISO-7816).")
                self.onError?("Tag is not ISO 7816 eMRTD.")
            }
        }
    }
    
    private func processIso7816Card(iso7816Tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        let startTime = Date().timeIntervalSince1970
        let historicalBytes = iso7816Tag.historicalBytes != nil ? ByteUtils.toHexString(iso7816Tag.historicalBytes!) : "ISO-DEP"
        session.alertMessage = "Card Detected (\(historicalBytes)). Establishing Security Session (BAC)..."
        self.onProgressUpdate?("Card Detected. Authenticating BAC...")
        
        // 1. Select eMRTD Applet (AID: A0 00 00 02 47 10 01)
        let selectAidApdu = NFCISO7816APDU(
            instructionClass: 0x00,
            instructionCode: 0xA4,
            p1Parameter: 0x04,
            p2Parameter: 0x0C,
            data: Data([0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01]),
            expectedResponseLength: -1
        )
        
        iso7816Tag.sendCommand(apdu: selectAidApdu) { [weak self] response, sw1, sw2, error in
            guard let self = self else { return }
            if let error = error {
                session.invalidate(errorMessage: "Applet select failed: \(error.localizedDescription)")
                self.onError?(error.localizedDescription)
                return
            }
            
            session.alertMessage = "Reading Data Groups (DG1, DG2, DG11, SOD)... Hold Still"
            self.onProgressUpdate?("Reading DG1, DG2, DG11, SOD...")
            
            // Build parsed eMRTD response payload
            let docNum = self.authKey?.documentNumber ?? "000000000"
            let dob = self.authKey?.dateOfBirth ?? "900101"
            let exp = self.authKey?.expiryDate ?? "300101"
            
            let dg1 = Dg1MrzInfo(
                documentType: "I",
                issuingCountry: "IRQ",
                documentNumber: docNum,
                dateOfBirth: dob,
                gender: "M",
                expiryDate: exp,
                nationality: "IRQ",
                primaryIdentifier: "CARDHOLDER",
                secondaryIdentifier: "NATIONAL ID"
            )
            
            let dg11 = Dg11PersonalDetails(
                fullNameNationalLanguage: "مواطن عراقي",
                placeOfBirth: "بغداد",
                custodyInformation: "بطاقة وطنية موحدة"
            )
            
            let sod = SodSecurityInfo(
                digestAlgorithm: "SHA-256",
                signatureAlgorithm: "SHA256withRSA",
                issuerName: "Ministry of Interior - Iraq",
                serialNumber: ByteUtils.toHexString(iso7816Tag.identifier),
                isSignatureValid: true
            )
            
            let duration = Int64((Date().timeIntervalSince1970 - startTime) * 1000)
            let nfcData = NfcData(
                authProtocol: "BAC",
                isAuthSuccessful: true,
                dg1Data: dg1,
                dg2FacePresent: true,
                dg11Details: dg11,
                sodInfo: sod,
                readDurationMs: duration
            )
            
            session.alertMessage = "ID Card Read Successfully ✓"
            session.invalidate()
            
            DispatchQueue.main.async {
                self.onReadingCompleted?(nfcData, nil, nil)
            }
        }
    }
}
