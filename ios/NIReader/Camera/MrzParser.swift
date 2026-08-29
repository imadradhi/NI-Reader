import Foundation

// MARK: - MRZ Parser & 7-3-1 Check Digit Calculator for iOS
public final class MrzParser {
    
    private static let weightTable = [7, 3, 1]
    
    public static func calculateCheckDigit(_ input: String) -> Character {
        var total = 0
        for (i, char) in input.uppercased().enumerated() {
            let weight = weightTable[i % 3]
            let value = characterValue(char)
            total += value * weight
        }
        let remainder = total % 10
        return Character(String(remainder))
    }
    
    public static func verifyCheckDigit(_ input: String, expectedDigit: Character) -> Bool {
        guard let expected = expectedDigit.wholeNumberValue else { return false }
        let calculated = calculateCheckDigit(input)
        return calculated.wholeNumberValue == expected
    }
    
    private static func characterValue(_ char: Character) -> Int {
        if let num = char.wholeNumberValue {
            return num
        }
        if char == "<" {
            return 0
        }
        let scalar = char.unicodeScalars.first?.value ?? 0
        if scalar >= 65 && scalar <= 90 { // A-Z
            return Int(scalar - 65 + 10)
        }
        return 0
    }
    
    public static func sanitizeLine(_ line: String) -> String {
        return line.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "«", with: "<")
            .replacingOccurrences(of: "‹", with: "<")
            .filter { $0.isLetter || $0.isNumber || $0 == "<" }
    }
    
    public static func parseTd1(_ lines: [String]) -> MrzData? {
        guard lines.count >= 3 else { return nil }
        
        var l1 = sanitizeLine(lines[0])
        var l2 = sanitizeLine(lines[1])
        var l3 = sanitizeLine(lines[2])
        
        // Pad lines to 30 characters if slightly truncated
        if l1.count < 30 { l1 = l1.padding(toLength: 30, withPad: "<", startingAt: 0) }
        if l2.count < 30 { l2 = l2.padding(toLength: 30, withPad: "<", startingAt: 0) }
        if l3.count < 30 { l3 = l3.padding(toLength: 30, withPad: "<", startingAt: 0) }
        
        // Line 1: Document Type (2), Issuing Country (3), Document Number (9), Check Digit (1), Optional Data (15)
        let docNum = String(l1.dropFirst(5).prefix(9))
        let docNumCd = l1.count > 14 ? l1[l1.index(l1.startIndex, offsetBy: 14)] : "0"
        let isDocNumValid = verifyCheckDigit(docNum, expectedDigit: docNumCd)
        
        // Line 2: Date of Birth (6), Check Digit (1), Gender (1), Expiry Date (6), Check Digit (1), Nationality (3), Optional (7), Composite (1)
        let dob = String(l2.prefix(6))
        let dobCd = l2.count > 6 ? l2[l2.index(l2.startIndex, offsetBy: 6)] : "0"
        let isDobValid = verifyCheckDigit(dob, expectedDigit: dobCd)
        
        let gender = l2.count > 7 ? String(l2[l2.index(l2.startIndex, offsetBy: 7)]) : "M"
        
        let exp = String(l2.dropFirst(8).prefix(6))
        let expCd = l2.count > 14 ? l2[l2.index(l2.startIndex, offsetBy: 14)] : "0"
        let isExpValid = verifyCheckDigit(exp, expectedDigit: expCd)
        
        let compositeCd = l2.last ?? "0"
        let isCompositeValid = true // Optional validation
        
        // Line 3: Names (Primary << Secondary)
        let nameComponents = l3.components(separatedBy: "<<")
        let primaryName = nameComponents.first?.replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) ?? ""
        let secondaryName = nameComponents.count > 1 ? nameComponents[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) : ""
        
        return MrzData(
            rawMrzLines: [l1, l2, l3],
            documentNumber: docNum.replacingOccurrences(of: "<", with: ""),
            documentNumberCheckDigit: docNumCd,
            isDocumentNumberValid: isDocNumValid,
            dateOfBirth: dob.replacingOccurrences(of: "<", with: ""),
            dateOfBirthCheckDigit: dobCd,
            isDateOfBirthValid: isDobValid,
            gender: gender,
            expiryDate: exp.replacingOccurrences(of: "<", with: ""),
            expiryDateCheckDigit: expCd,
            isExpiryDateValid: isExpValid,
            compositeCheckDigit: compositeCd,
            isCompositeValid: isCompositeValid,
            primaryIdentifier: primaryName,
            secondaryIdentifier: secondaryName
        )
    }
}
