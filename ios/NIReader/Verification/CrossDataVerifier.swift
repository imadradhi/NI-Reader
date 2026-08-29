import Foundation

// MARK: - Cross-Data Verification Engine for iOS
public final class CrossDataVerifier {
    
    public static func verify(mrzData: MrzData?, nfcData: NfcData?) -> VerificationReport {
        var checks: [FieldMatchCheck] = []
        var failureReasons: [String] = []
        
        let isOcrAvailable = mrzData != nil
        let isNfcAvailable = nfcData != nil && nfcData!.isAuthSuccessful
        
        let ocrStatus: VerificationStatus = isOcrAvailable ?
            ((mrzData!.isDocumentNumberValid && mrzData!.isDateOfBirthValid) ? .pass : .warning) : .failed
        
        let nfcStatus: VerificationStatus = isNfcAvailable ? .pass : .failed
        
        if !isOcrAvailable {
            failureReasons.append("OCR MRZ data missing or unreadable")
        }
        if !isNfcAvailable {
            failureReasons.append("NFC Chip data missing or authentication failed")
        }
        
        if let mrz = mrzData, let nfc = nfcData, let dg1 = nfc.dg1Data {
            // 1. Document Number Check
            let ocrDoc = mrz.documentNumber.trimmingCharacters(in: .whitespaces)
            let nfcDoc = dg1.documentNumber.trimmingCharacters(in: .whitespaces)
            let isDocMatch = ocrDoc.caseInsensitiveCompare(nfcDoc) == .orderedSame
            checks.append(FieldMatchCheck(fieldName: "Document Number", ocrValue: ocrDoc, nfcValue: nfcDoc, isMatch: isDocMatch))
            if !isDocMatch {
                failureReasons.append("Document Number mismatch (OCR: '\(ocrDoc)', NFC: '\(nfcDoc)')")
            }
            
            // 2. Date of Birth Check
            let ocrDob = mrz.dateOfBirth.trimmingCharacters(in: .whitespaces)
            let nfcDob = dg1.dateOfBirth.trimmingCharacters(in: .whitespaces)
            let isDobMatch = ocrDob == nfcDob
            checks.append(FieldMatchCheck(fieldName: "Date of Birth", ocrValue: ocrDob, nfcValue: nfcDob, isMatch: isDobMatch))
            if !isDobMatch {
                failureReasons.append("Date of Birth mismatch (OCR: '\(ocrDob)', NFC: '\(nfcDob)')")
            }
            
            // 3. Expiry Date Check
            let ocrExp = mrz.expiryDate.trimmingCharacters(in: .whitespaces)
            let nfcExp = dg1.expiryDate.trimmingCharacters(in: .whitespaces)
            let isExpMatch = ocrExp == nfcExp
            checks.append(FieldMatchCheck(fieldName: "Expiry Date", ocrValue: ocrExp, nfcValue: nfcExp, isMatch: isExpMatch))
            if !isExpMatch {
                failureReasons.append("Expiry Date mismatch (OCR: '\(ocrExp)', NFC: '\(nfcExp)')")
            }
            
            // 4. Gender Check
            let ocrGender = mrz.gender.trimmingCharacters(in: .whitespaces)
            let nfcGender = dg1.gender.trimmingCharacters(in: .whitespaces)
            let isGenderMatch = ocrGender.caseInsensitiveCompare(nfcGender) == .orderedSame || ocrGender.isEmpty
            checks.append(FieldMatchCheck(fieldName: "Gender", ocrValue: ocrGender, nfcValue: nfcGender, isMatch: isGenderMatch))
            
            // 5. Name Check
            let ocrName = "\(mrz.primaryIdentifier) \(mrz.secondaryIdentifier)".trimmingCharacters(in: .whitespaces)
            let nfcName = "\(dg1.primaryIdentifier) \(dg1.secondaryIdentifier)".trimmingCharacters(in: .whitespaces)
            let sim = stringSimilarity(ocrName, nfcName)
            let isNameMatch = ocrName.caseInsensitiveCompare(nfcName) == .orderedSame || sim >= 0.85
            checks.append(FieldMatchCheck(fieldName: "Name", ocrValue: ocrName, nfcValue: nfcName, isMatch: isNameMatch, similarityScore: sim))
            if !isNameMatch {
                failureReasons.append("Name mismatch (OCR: '\(ocrName)', NFC: '\(nfcName)')")
            }
        }
        
        let allChecksPassed = !checks.isEmpty && checks.allSatisfy { $0.isMatch }
        let matchingStatus: VerificationStatus = allChecksPassed ? .pass : (!checks.isEmpty ? .failed : .skipped)
        
        let overallStatus: VerificationStatus = (ocrStatus == .pass && nfcStatus == .pass && matchingStatus == .pass) ? .pass : .failed
        
        return VerificationReport(
            ocrStatus: ocrStatus,
            nfcStatus: nfcStatus,
            matchingStatus: matchingStatus,
            overallStatus: overallStatus,
            fieldChecks: checks,
            failureReasons: failureReasons
        )
    }
    
    private static func stringSimilarity(_ s1: String, _ s2: String) -> Float {
        if s1.caseInsensitiveCompare(s2) == .orderedSame { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }
        let dist = levenshtein(s1.uppercased(), s2.uppercased())
        let maxLen = max(s1.count, s2.count)
        return max(0.0, min(1.0, 1.0 - (Float(dist) / Float(maxLen))))
    }
    
    private static func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count { matrix[i][0] = i }
        for j in 0...b.count { matrix[0][j] = j }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + 1)
                }
            }
        }
        return matrix[a.count][b.count]
    }
}
