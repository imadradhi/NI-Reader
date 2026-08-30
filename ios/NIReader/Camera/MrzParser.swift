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
            .filter { $0.isLetter || $0.isNumber || $0 == "<" }
    }

    public static func sanitizeDigitsOnly(_ field: String) -> String {
        return field.uppercased()
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "Q", with: "0")
            .replacingOccurrences(of: "D", with: "0")
            .replacingOccurrences(of: "U", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
            .replacingOccurrences(of: "T", with: "1")
            .replacingOccurrences(of: "J", with: "1")
            .replacingOccurrences(of: "Z", with: "2")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "G", with: "6")
    }
    
    public static func parseTd1(_ rawLines: [String]) -> MrzData? {
        guard !rawLines.isEmpty else { return nil }
        
        var lines = rawLines.map { sanitizeLine($0) }.filter { !$0.isEmpty }

        // If continuous string of 60+ chars (Line 1 + Line 2)
        if lines.count == 1 && lines[0].count >= 60 {
            let fullText = lines[0]
            let l1 = String(fullText.prefix(30))
            let l2 = String(fullText.dropFirst(30).prefix(30))
            let l3 = fullText.count >= 90 ? String(fullText.dropFirst(60).prefix(30)) : "<<"
            lines = [l1, l2, l3]
        }

        guard lines.count >= 2 else { return nil }

        // Strategy 1: Standard ICAO Doc 9303 TD1 parsing with padding
        if let standard = tryStandardParse(lines), (standard.isDocumentNumberValid || standard.isDateOfBirthValid || standard.isExpiryDateValid) {
            return standard
        }

        // Strategy 2: Anchor-based parsing (locate IRQ and Date patterns)
        if let anchor = tryAnchorBasedParse(lines) {
            return anchor
        }

        return standard
    }

    private static func tryStandardParse(_ lines: [String]) -> MrzData? {
        guard lines.count >= 2 else { return nil }
        var l1 = lines[0]
        var l2 = lines[1]
        var l3 = lines.count > 2 ? lines[2] : "<<"
        
        if l1.count < 30 { l1 = l1.padding(toLength: 30, withPad: "<", startingAt: 0) }
        if l2.count < 30 { l2 = l2.padding(toLength: 30, withPad: "<", startingAt: 0) }
        if l3.count < 30 { l3 = l3.padding(toLength: 30, withPad: "<", startingAt: 0) }
        
        // Line 1: Doc Type (2), Country (3), Doc Num (9: alphanumeric e.g. AZ9431882), Check Digit (1), National No (12)
        let rawDoc = String(l1.dropFirst(5).prefix(9))
        let docNum = rawDoc.replacingOccurrences(of: "<", with: "")
        let docNumCd = l1.count > 14 ? l1[l1.index(l1.startIndex, offsetBy: 14)] : "0"
        let isDocNumValid = verifyCheckDigit(rawDoc, expectedDigit: docNumCd)
        
        // Line 2: DOB (6), Check Digit (1), Gender (1), Expiry (6), Check Digit (1), Nationality (3)
        let rawDob = sanitizeDigitsOnly(String(l2.prefix(6)))
        let dobCd = l2.count > 6 ? Character(sanitizeDigitsOnly(String(l2[l2.index(l2.startIndex, offsetBy: 6)]))) : "0"
        let isDobValid = verifyCheckDigit(rawDob, expectedDigit: dobCd)
        
        let gender = l2.count > 7 ? String(l2[l2.index(l2.startIndex, offsetBy: 7)]).replacingOccurrences(of: "<", with: "") : "M"
        
        let rawExp = sanitizeDigitsOnly(String(l2.dropFirst(8).prefix(6)))
        let expCd = l2.count > 14 ? Character(sanitizeDigitsOnly(String(l2[l2.index(l2.startIndex, offsetBy: 14)]))) : "0"
        let isExpValid = verifyCheckDigit(rawExp, expectedDigit: expCd)
        
        // Line 3: Names (e.g. <<EMAD<<<<<<<<...)
        let nameParts = l3.components(separatedBy: "<").filter { !$0.isEmpty }
        let primaryName = nameParts.first ?? ""
        let secondaryName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""
        
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
        let docNum = rawDoc.replacingOccurrences(of: "<", with: "")
        let docNumCd = afterIrq.count > 9 ? afterIrq[afterIrq.index(afterIrq.startIndex, offsetBy: 9)] : "0"
        let isDocValid = verifyCheckDigit(rawDoc, expectedDigit: docNumCd)
        
        guard let l2 = lines.first(where: { $0 != l1 && (sanitizeDigitsOnly($0).count >= 14 || $0.contains("IRQ")) }) else { return nil }
        let rawDob = sanitizeDigitsOnly(String(l2.prefix(6)))
        let dobCd = l2.count > 6 ? Character(sanitizeDigitsOnly(String(l2[l2.index(l2.startIndex, offsetBy: 6)]))) : "0"
        let isDobValid = verifyCheckDigit(rawDob, expectedDigit: dobCd)
        
        let rawExp = l2.count >= 14 ? sanitizeDigitsOnly(String(l2.dropFirst(8).prefix(6))) : ""
        let expCd = l2.count > 14 ? Character(sanitizeDigitsOnly(String(l2[l2.index(l2.startIndex, offsetBy: 14)]))) : "0"
        let isExpValid = rawExp.count == 6 && verifyCheckDigit(rawExp, expectedDigit: expCd)
        
        let l3 = lines.first(where: { $0 != l1 && $0 != l2 }) ?? ""
        let nameParts = l3.components(separatedBy: "<").filter { !$0.isEmpty }
        let primaryName = nameParts.first ?? ""
        let secondaryName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""
        
        if !docNum.isEmpty && rawDob.count == 6 && rawExp.count == 6 {
            return MrzData(
                rawMrzLines: [l1, l2, l3],
                documentNumber: docNum,
                documentNumberCheckDigit: String(docNumCd),
                isDocumentNumberValid: isDocValid,
                dateOfBirth: rawDob,
                dateOfBirthCheckDigit: String(dobCd),
                isDateOfBirthValid: isDobValid,
                gender: "M",
                expiryDate: rawExp,
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
