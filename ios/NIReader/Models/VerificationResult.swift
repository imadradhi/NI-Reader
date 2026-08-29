import Foundation

public enum VerificationStatus: String, Codable {
    case pass = "PASS"
    case failed = "FAILED"
    case skipped = "SKIPPED"
    case warning = "WARNING"
}

public struct VerificationReport: Codable {
    public let ocrStatus: VerificationStatus
    public let nfcStatus: VerificationStatus
    public let matchingStatus: VerificationStatus
    public let overallStatus: VerificationStatus
    public let fieldChecks: [FieldMatchCheck]
    public let failureReasons: [String]
    
    public init(
        ocrStatus: VerificationStatus,
        nfcStatus: VerificationStatus,
        matchingStatus: VerificationStatus,
        overallStatus: VerificationStatus,
        fieldChecks: [FieldMatchCheck],
        failureReasons: [String] = []
    ) {
        self.ocrStatus = ocrStatus
        self.nfcStatus = nfcStatus
        self.matchingStatus = matchingStatus
        self.overallStatus = overallStatus
        self.fieldChecks = fieldChecks
        self.failureReasons = failureReasons
    }
}

public struct FieldMatchCheck: Codable {
    public let fieldName: String
    public let ocrValue: String
    public let nfcValue: String
    public let isMatch: Bool
    public let similarityScore: Float
    
    public init(fieldName: String, ocrValue: String, nfcValue: String, isMatch: Bool, similarityScore: Float = 1.0) {
        self.fieldName = fieldName
        self.ocrValue = ocrValue
        self.nfcValue = nfcValue
        self.isMatch = isMatch
        self.similarityScore = similarityScore
    }
}

// MARK: - Desktop API Responses
public struct DesktopApiResponse: Codable {
    public let status: String
    public let message: String?
    public let transactionId: String?
}

public struct HealthCheckResponse: Codable {
    public let status: String
    public let service: String?
    public let timestamp: Int64?
}
