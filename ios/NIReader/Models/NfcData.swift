import Foundation

public struct NfcData: Codable {
    public let authProtocol: String
    public let isAuthSuccessful: Bool
    public let dg1Data: Dg1MrzInfo?
    public let dg2FacePresent: Bool
    public let dg11Details: Dg11PersonalDetails?
    public let dg13Details: [String: String]?
    public let sodInfo: SodSecurityInfo?
    public let readDurationMs: Int64
    
    public init(
        authProtocol: String = "BAC",
        isAuthSuccessful: Bool = true,
        dg1Data: Dg1MrzInfo? = nil,
        dg2FacePresent: Bool = false,
        dg11Details: Dg11PersonalDetails? = nil,
        dg13Details: [String: String]? = nil,
        sodInfo: SodSecurityInfo? = nil,
        readDurationMs: Int64 = 0
    ) {
        self.authProtocol = authProtocol
        self.isAuthSuccessful = isAuthSuccessful
        self.dg1Data = dg1Data
        self.dg2FacePresent = dg2FacePresent
        self.dg11Details = dg11Details
        self.dg13Details = dg13Details
        self.sodInfo = sodInfo
        self.readDurationMs = readDurationMs
    }
}

public struct Dg1MrzInfo: Codable {
    public let documentType: String
    public let issuingCountry: String
    public let documentNumber: String
    public let dateOfBirth: String
    public let gender: String
    public let expiryDate: String
    public let nationality: String
    public let primaryIdentifier: String
    public let secondaryIdentifier: String
    
    public init(
        documentType: String,
        issuingCountry: String,
        documentNumber: String,
        dateOfBirth: String,
        gender: String,
        expiryDate: String,
        nationality: String,
        primaryIdentifier: String,
        secondaryIdentifier: String
    ) {
        self.documentType = documentType
        self.issuingCountry = issuingCountry
        self.documentNumber = documentNumber
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.expiryDate = expiryDate
        self.nationality = nationality
        self.primaryIdentifier = primaryIdentifier
        self.secondaryIdentifier = secondaryIdentifier
    }
}

public struct Dg11PersonalDetails: Codable {
    public let fullNameNationalLanguage: String?
    public let placeOfBirth: String?
    public let telephone: String?
    public let profession: String?
    public let title: String?
    public let personalSummary: String?
    public let custodyInformation: String?
    
    public init(
        fullNameNationalLanguage: String? = nil,
        placeOfBirth: String? = nil,
        telephone: String? = nil,
        profession: String? = nil,
        title: String? = nil,
        personalSummary: String? = nil,
        custodyInformation: String? = nil
    ) {
        self.fullNameNationalLanguage = fullNameNationalLanguage
        self.placeOfBirth = placeOfBirth
        self.telephone = telephone
        self.profession = profession
        self.title = title
        self.personalSummary = personalSummary
        self.custodyInformation = custodyInformation
    }
}

public struct SodSecurityInfo: Codable {
    public let digestAlgorithm: String?
    public let signatureAlgorithm: String?
    public let issuerName: String?
    public let serialNumber: String?
    public let isSignatureValid: Bool?
    
    public init(
        digestAlgorithm: String? = nil,
        signatureAlgorithm: String? = nil,
        issuerName: String? = nil,
        serialNumber: String? = nil,
        isSignatureValid: Bool? = nil
    ) {
        self.digestAlgorithm = digestAlgorithm
        self.signatureAlgorithm = signatureAlgorithm
        self.issuerName = issuerName
        self.serialNumber = serialNumber
        self.isSignatureValid = isSignatureValid
    }
}
