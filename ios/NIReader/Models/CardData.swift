import Foundation

// MARK: - Unified Card Payload matching Desktop Receiver & Android JSON Schema
public struct CardDataPayload: Codable {
    public let cardData: CardDataContent
    public let timestamp: Int64
    public let deviceId: String
    
    public init(cardData: CardDataContent, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), deviceId: String = "iOS-Companion-Reader") {
        self.cardData = cardData
        self.timestamp = timestamp
        self.deviceId = deviceId
    }
}

public struct CardDataContent: Codable {
    public let personalData: PersonalData
    public let mrzData: MrzData?
    public let nfcData: NfcData?
    public let images: CardImages
    public let verification: VerificationReport?
    
    public init(personalData: PersonalData, mrzData: MrzData?, nfcData: NfcData?, images: CardImages, verification: VerificationReport?) {
        self.personalData = personalData
        self.mrzData = mrzData
        self.nfcData = nfcData
        self.images = images
        self.verification = verification
    }
}

public struct PersonalData: Codable {
    public let nationalIdNumber: String
    public let fullNameArabic: String?
    public let fullNameEnglish: String
    public let dateOfBirth: String
    public let gender: String
    public let expiryDate: String
    public let nationality: String
    public let province: String?
    public let custodyInformation: String?
    
    public init(
        nationalIdNumber: String,
        fullNameArabic: String? = nil,
        fullNameEnglish: String,
        dateOfBirth: String,
        gender: String,
        expiryDate: String,
        nationality: String = "IRQ",
        province: String? = nil,
        custodyInformation: String? = nil
    ) {
        self.nationalIdNumber = nationalIdNumber
        self.fullNameArabic = fullNameArabic
        self.fullNameEnglish = fullNameEnglish
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.expiryDate = expiryDate
        self.nationality = nationality
        self.province = province
        self.custodyInformation = custodyInformation
    }
}

public struct CardImages: Codable {
    public let frontImageBase64: String?
    public let backImageBase64: String?
    public let chipPhotoBase64: String?
    
    public init(frontImageBase64: String? = nil, backImageBase64: String? = nil, chipPhotoBase64: String? = nil) {
        self.frontImageBase64 = frontImageBase64
        self.backImageBase64 = backImageBase64
        self.chipPhotoBase64 = chipPhotoBase64
    }
}
