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
            .replacingOccurrences(of: "»", with: "<")
            .replacingOccurrences(of: "‹", with: "<")
            .replacingOccurrences(of: "(", with: "<")
            .replacingOccurrences(of: ")", with: "<")
            .replacingOccurrences(of: "{", with: "<")
            .replacingOccurrences(of: "}", with: "<")
            .replacingOccurrences(of: "[", with: "<")
            .replacingOccurrences(of: "]", with: "<")
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "—", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    public static func sanitizeNumericField(_ field: String) -> String {
        return field.uppercased()
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "Q", with: "0")
            .replacingOccurrences(of: "D", with: "0")
            .replacingOccurrences(of: "U", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
            .replacingOccurrences(of: "T", with: "1")
            .replacingOccurrences(of: "Z", with: "2")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "G", with: "6")
    }
    
    public static func parseTd1(_ rawLines: [String]) -> MrzData? {
        guard rawLines.count >= 3 else { return nil }
        
        let lines = rawLines.map { sanitizeLine($0) }

        // Strategy 1: Standard ICAO Doc 9303 TD1 parsing with padding
        if let standard = tryStandardParse(lines), (standard.isDocumentNumberValid || standard.isDateOfBirthValid || standard.isExpiryDateValid) {
            return standard
        }

        // Strategy 2: Anchor-based parsing (locate IRQ and Date patterns)
        if let anchor = tryAnchorBasedParse(lines) {
            return anchor
        }

        return tryStandardParse(lines)
    }

    private static func tryStandardParse(_ lines: [String]) -> MrzData? {
        guard lines.count >= 3 else { return nil }
        var l1 = lines[0]
        var l2 = lines[1]
        var l3 = lines[2]
        
        if l1.count < 30 { l1 = l1.padding(toLength: 30, withPad: "<", startingAt: 0) }
        if l2.count < 30 { l2 = l2.padding(toLength: 30, withPad: "<", startingAt: 0) }
        if l3.count < 30 { l3 = l3.padding(toLength: 30, withPad: "<", startingAt: 0) }
        
        // Line 1: Doc Type (2), Country (3), Doc Num (9), Check Digit (1), Optional (15)
        let rawDoc = String(l1.dropFirst(5).prefix(9))
        let docNum = sanitizeNumericField(rawDoc).replacingOccurrences(of: "<", with: "")
        let docNumCd = l1.count > 14 ? Character(sanitizeNumericField(String(l1[l1.index(l1.startIndex, offsetBy: 14)]))) : "0"
        let isDocNumValid = verifyCheckDigit(rawDoc, expectedDigit: docNumCd)
        
        // Line 2: DOB (6), Check Digit (1), Gender (1), Expiry (6), Check Digit (1), Nationality (3)
        let rawDob = sanitizeNumericField(String(l2.prefix(6)))
        let dobCd = l2.count > 6 ? Character(sanitizeNumericField(String(l2[l2.index(l2.startIndex, offsetBy: 6)]))) : "0"
        let isDobValid = verifyCheckDigit(rawDob, expectedDigit: dobCd)
        
        let gender = l2.count > 7 ? String(l2[l2.index(l2.startIndex, offsetBy: 7)]).replacingOccurrences(of: "<", with: "") : "M"
        
        let rawExp = sanitizeNumericField(String(l2.dropFirst(8).prefix(6)))
        let expCd = l2.count > 14 ? Character(sanitizeNumericField(String(l2[l2.index(l2.startIndex, offsetBy: 14)]))) : "0"
        let isExpValid = verifyCheckDigit(rawExp, expectedDigit: expCd)
        
        // Line 3: Names (Primary << Secondary)
        let nameComponents = l3.components(separatedBy: "<<")
        let primaryName = nameComponents.first?.replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) ?? ""
        let secondaryName = nameComponents.count > 1 ? nameComponents[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) : ""
        
        return MrzData(
            rawMrzLines: [l1, l2, l3],
            documentNumber: docNum,
            documentNumberCheckDigit: String(docNumCd),
            isDocumentNumberValid: isDocNumValid,
            dateOfBirth: rawDob,
            dateOfBirthCheckDigit: String(dobCd),
            isDateOfBirthValid: isDobValid,
            gender: gender.isEmpty ? "M" : gender,
            expiryDate: rawExp,
            expiryDateCheckDigit: String(expCd),
            isExpiryDateValid: isExpValid,
            compositeCheckDigit: "0",
            isCompositeValid: true,
            primaryIdentifier: primaryName,
            secondaryIdentifier: secondaryName
        )
    }

    private static func tryAnchorBasedParse(_ lines: [String]) -> MrzData? {
        guard let l1 = lines.first(where: { $0.contains("IRQ") && $0.count >= 14 }) else { return nil }
        guard let irqRange = l1.range(of: "IRQ") else { return nil }
        let afterIrq = String(l1[irqRange.upperBound...])
        guard afterIrq.count >= 9 else { return nil }
        
        let rawDoc = String(afterIrq.prefix(9))
        let docNum = sanitizeNumericField(rawDoc).replacingOccurrences(of: "<", with: "")
        let docNumCd = afterIrq.count > 9 ? Character(sanitizeNumericField(String(afterIrq[afterIrq.index(afterIrq.startIndex, offsetBy: 9)]))) : "0"
        let isDocValid = verifyCheckDigit(rawDoc, expectedDigit: docNumCd)
        
        guard let l2 = lines.first(where: { $0 != l1 && sanitizeNumericField($0).count >= 14 }) else { return nil }
        let numL2 = sanitizeNumericField(l2)
        let dob = String(numL2.prefix(6))
        let dobCd = numL2.count > 6 ? numL2[numL2.index(numL2.startIndex, offsetBy: 6)] : "0"
        let isDobValid = verifyCheckDigit(dob, expectedDigit: dobCd)
        
        let exp = numL2.count >= 14 ? String(numL2.dropFirst(8).prefix(6)) : ""
        let expCd = numL2.count > 14 ? numL2[numL2.index(numL2.startIndex, offsetBy: 14)] : "0"
        let isExpValid = exp.count == 6 && verifyCheckDigit(exp, expectedDigit: expCd)
        
        let l3 = lines.first(where: { $0 != l1 && $0 != l2 }) ?? ""
        let nameComponents = l3.components(separatedBy: "<<")
        let primaryName = nameComponents.first?.replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) ?? ""
        let secondaryName = nameComponents.count > 1 ? nameComponents[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) : ""
        
        if !docNum.isEmpty && dob.count == 6 && exp.count == 6 {
            return MrzData(
                rawMrzLines: [l1, l2, l3],
                documentNumber: docNum,
                documentNumberCheckDigit: String(docNumCd),
                isDocumentNumberValid: isDocValid,
                dateOfBirth: dob,
                dateOfBirthCheckDigit: String(dobCd),
                isDateOfBirthValid: isDobValid,
                gender: "M",
                expiryDate: exp,
                expiryDateCheckDigit: String(expCd),
                isExpiryDateValid: isExpValid,
                compositeCheckDigit: "0",
                isCompositeValid: true,
                primaryIdentifier: primaryName,
                secondaryIdentifier: secondaryName
            )
        }
        return nil
    }
}
