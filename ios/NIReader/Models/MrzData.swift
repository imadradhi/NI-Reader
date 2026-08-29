import Foundation

public struct MrzData: Codable, Equatable {
    public let rawMrzLines: [String]
    public let documentNumber: String
    public let documentNumberCheckDigit: Character
    public let isDocumentNumberValid: BooleanLiteralType
    public let dateOfBirth: String
    public let dateOfBirthCheckDigit: Character
    public let isDateOfBirthValid: BooleanLiteralType
    public let gender: String
    public let expiryDate: String
    public let expiryDateCheckDigit: Character
    public let isExpiryDateValid: BooleanLiteralType
    public let compositeCheckDigit: Character
    public let isCompositeValid: BooleanLiteralType
    public let primaryIdentifier: String
    public let secondaryIdentifier: String
    
    public init(
        rawMrzLines: [String],
        documentNumber: String,
        documentNumberCheckDigit: Character,
        isDocumentNumberValid: Bool,
        dateOfBirth: String,
        dateOfBirthCheckDigit: Character,
        isDateOfBirthValid: Bool,
        gender: String,
        expiryDate: String,
        expiryDateCheckDigit: Character,
        isExpiryDateValid: Bool,
        compositeCheckDigit: Character,
        isCompositeValid: Bool,
        primaryIdentifier: String,
        secondaryIdentifier: String
    ) {
        self.rawMrzLines = rawMrzLines
        self.documentNumber = documentNumber
        self.documentNumberCheckDigit = documentNumberCheckDigit
        self.isDocumentNumberValid = isDocumentNumberValid
        self.dateOfBirth = dateOfBirth
        self.dateOfBirthCheckDigit = dateOfBirthCheckDigit
        self.isDateOfBirthValid = isDateOfBirthValid
        self.gender = gender
        self.expiryDate = expiryDate
        self.expiryDateCheckDigit = expiryDateCheckDigit
        self.isExpiryDateValid = isExpiryDateValid
        self.compositeCheckDigit = compositeCheckDigit
        self.isCompositeValid = isCompositeValid
        self.primaryIdentifier = primaryIdentifier
        self.secondaryIdentifier = secondaryIdentifier
    }
    
    public func formattedDob() -> String {
        guard dateOfBirth.count == 6 else { return dateOfBirth }
        let yy = String(dateOfBirth.prefix(2))
        let mm = String(dateOfBirth.dropFirst(2).prefix(2))
        let dd = String(dateOfBirth.suffix(2))
        let fullYear = (Int(yy) ?? 0) > 40 ? "19\(yy)" : "20\(yy)"
        return "\(fullYear)-\(mm)-\(dd)"
    }
    
    public func formattedExpiry() -> String {
        guard expiryDate.count == 6 else { return expiryDate }
        let yy = String(expiryDate.prefix(2))
        let mm = String(expiryDate.dropFirst(2).prefix(2))
        let dd = String(expiryDate.suffix(2))
        let fullYear = "20\(yy)"
        return "\(fullYear)-\(mm)-\(dd)"
    }
}
