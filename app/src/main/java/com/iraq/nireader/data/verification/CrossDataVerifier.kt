package com.iraq.nireader.data.verification

import com.iraq.nireader.data.model.*

/**
 * Cross-verification engine that compares OCR extracted data with electronic NFC chip data.
 */
object CrossDataVerifier {

    /**
     * Executes cross-comparison between OCR extracted MRZ data and NFC chip data.
     */
    fun verify(mrzData: MrzData?, nfcData: NfcData?): VerificationReport {
        val checks = mutableListOf<FieldMatchCheck>()
        val failureReasons = mutableListOf<String>()

        val isOcrAvailable = mrzData != null
        val isNfcAvailable = nfcData != null && nfcData.isAuthSuccessful

        val ocrStatus = if (isOcrAvailable) {
            if (mrzData!!.isDocumentNumberValid && mrzData.isDateOfBirthValid) VerificationStatus.PASS else VerificationStatus.WARNING
        } else {
            VerificationStatus.FAILED
        }

        val nfcStatus = if (isNfcAvailable) VerificationStatus.PASS else VerificationStatus.FAILED

        if (!isOcrAvailable) {
            failureReasons.add("OCR MRZ data missing or unreadable")
        }
        if (!isNfcAvailable) {
            failureReasons.add("NFC Chip data missing or authentication failed")
        }

        if (isOcrAvailable && isNfcAvailable) {
            val dg1 = nfcData?.dg1Data

            // 1. Document Number Check
            val ocrDocNum = mrzData!!.documentNumber.replace("<", "").trim()
            val nfcDocNum = dg1?.documentNumber?.replace("<", "")?.trim() ?: ""
            val isDocNumMatch = ocrDocNum.equals(nfcDocNum, ignoreCase = true)
            checks.add(FieldMatchCheck("Document Number", ocrDocNum, nfcDocNum, isDocNumMatch))
            if (!isDocNumMatch) {
                failureReasons.add("Document Number mismatch (OCR: '$ocrDocNum', NFC: '$nfcDocNum')")
            }

            // 2. Date of Birth Check
            val ocrDob = mrzData.dateOfBirth.replace("<", "").trim()
            val nfcDob = dg1?.dateOfBirth?.replace("<", "")?.trim() ?: ""
            val isDobMatch = ocrDob == nfcDob
            checks.add(FieldMatchCheck("Date of Birth", ocrDob, nfcDob, isDobMatch))
            if (!isDobMatch) {
                failureReasons.add("Date of Birth mismatch (OCR: '$ocrDob', NFC: '$nfcDob')")
            }

            // 3. Expiry Date Check
            val ocrExp = mrzData.expiryDate.replace("<", "").trim()
            val nfcExp = dg1?.expiryDate?.replace("<", "")?.trim() ?: ""
            val isExpMatch = ocrExp == nfcExp
            checks.add(FieldMatchCheck("Expiry Date", ocrExp, nfcExp, isExpMatch))
            if (!isExpMatch) {
                failureReasons.add("Expiry Date mismatch (OCR: '$ocrExp', NFC: '$nfcExp')")
            }

            // 4. Gender Check
            val ocrGender = mrzData.gender.trim()
            val nfcGender = dg1?.gender?.trim() ?: ""
            val isGenderMatch = ocrGender.equals(nfcGender, ignoreCase = true) || ocrGender.isEmpty()
            checks.add(FieldMatchCheck("Gender", ocrGender, nfcGender, isGenderMatch))

            // 5. Name Check
            val ocrName = "${mrzData.primaryIdentifier} ${mrzData.secondaryIdentifier}".trim()
            val nfcName = "${dg1?.primaryIdentifier.orEmpty()} ${dg1?.secondaryIdentifier.orEmpty()}".trim()
            val isNameMatch = ocrName.equals(nfcName, ignoreCase = true) || calculateStringSimilarity(ocrName, nfcName) >= 0.85f
            val simScore = calculateStringSimilarity(ocrName, nfcName)
            checks.add(FieldMatchCheck("Name", ocrName, nfcName, isNameMatch, simScore))
            if (!isNameMatch) {
                failureReasons.add("Name mismatch (OCR: '$ocrName', NFC: '$nfcName')")
            }
        }

        val allChecksPassed = checks.isNotEmpty() && checks.all { it.isMatch }
        val matchingStatus = if (allChecksPassed) VerificationStatus.PASS else if (checks.isNotEmpty()) VerificationStatus.FAILED else VerificationStatus.SKIPPED

        val overallStatus = if (ocrStatus == VerificationStatus.PASS && nfcStatus == VerificationStatus.PASS && matchingStatus == VerificationStatus.PASS) {
            VerificationStatus.PASS
        } else {
            VerificationStatus.FAILED
        }

        return VerificationReport(
            ocrStatus = ocrStatus,
            nfcStatus = nfcStatus,
            matchingStatus = matchingStatus,
            overallStatus = overallStatus,
            fieldChecks = checks,
            failureReasons = failureReasons
        )
    }

    private fun calculateStringSimilarity(s1: String, s2: String): Float {
        if (s1.equals(s2, ignoreCase = true)) return 1.0f
        if (s1.isEmpty() || s2.isEmpty()) return 0.0f
        val distance = levenshtein(s1.uppercase(), s2.uppercase())
        val maxLen = maxOf(s1.length, s2.length)
        return (1.0f - (distance.toFloat() / maxLen)).coerceIn(0.0f, 1.0f)
    }

    private fun levenshtein(lhs: CharSequence, rhs: CharSequence): Int {
        var cost = Array(lhs.length + 1) { it }
        var newCost = Array(lhs.length + 1) { 0 }

        for (i in 1..rhs.length) {
            newCost[0] = i
            for (j in 1..lhs.length) {
                val match = if (lhs[j - 1] == rhs[i - 1]) 0 else 1
                val costReplace = cost[j - 1] + match
                val costInsert = cost[j] + 1
                val costDelete = newCost[j - 1] + 1
                newCost[j] = minOf(costInsert, costDelete, costReplace)
            }
            val swap = cost
            cost = newCost
            newCost = swap
        }
        return cost[lhs.length]
    }
}
