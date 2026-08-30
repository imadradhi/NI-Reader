package com.iraq.nireader.data.ocr

import com.iraq.nireader.data.model.MrzData
import com.iraq.nireader.data.nfc.NfcAuthKey

/**
 * Parses and sanitizes TD1 (3 lines x 30 characters) MRZ from the Iraqi National ID.
 * Format:
 * Line 1: IDIRQ + DocNo(9 chars: e.g. AZ9431882) + Check(1) + NationalNo(12) + <<<
 * Line 2: DOB(6: YYMMDD) + Check(1) + Sex(1: M/F) + Expiry(6: YYMMDD) + Check(1) + IRQ + <<<<<<<<< + CompositeCheck(1)
 * Line 3: << + First/Full Name + <<<<<<<<<<<<<<<
 */
object MrzParser {

    /**
     * Cleans common OCR recognition noise in MRZ lines.
     */
    fun sanitizeLine(line: String): String {
        return line.trim()
            .uppercase()
            .replace(" ", "")
            .replace("«", "<")
            .replace("»", "<")
            .replace("‹", "<")
            .replace("(", "<")
            .replace(")", "<")
            .replace("{", "<")
            .replace("}", "<")
            .replace("[", "<")
            .replace("]", "<")
            .replace("|", "")
            .replace("—", "")
            .replace("-", "")
            .filter { it.isLetter() || it.isDigit() || it == '<' }
    }

    /**
     * Fixes purely numeric fields (e.g. Dates) where letters were misread.
     */
    fun sanitizeDigitsOnly(field: String): String {
        return field.uppercase()
            .replace('O', '0')
            .replace('Q', '0')
            .replace('D', '0')
            .replace('U', '0')
            .replace('I', '1')
            .replace('L', '1')
            .replace('T', '1')
            .replace('J', '1')
            .replace('Z', '2')
            .replace('B', '8')
            .replace('S', '5')
            .replace('G', '6')
    }

    /**
     * Parses TD1 MRZ from the Iraqi National ID (accepts 60 characters / 2 core lines or full 3 lines).
     */
    fun parseTd1(rawLines: List<String>): MrzData? {
        if (rawLines.isEmpty()) return null

        var lines = rawLines.map { sanitizeLine(it) }.filter { it.isNotBlank() }
        
        // If passed a single continuous string of 60+ chars (e.g. Line1 + Line2)
        if (lines.size == 1 && lines[0].length >= 60) {
            val fullText = lines[0]
            val l1 = fullText.substring(0, 30)
            val l2 = fullText.substring(30, 60)
            val l3 = if (fullText.length >= 90) fullText.substring(60, 90) else "<<"
            lines = listOf(l1, l2, l3)
        }

        if (lines.size < 2) return null

        // Strategy 1: Standard index-based parse
        val standard = tryStandardParse(lines)
        if (standard != null && (standard.isDocumentNumberValid || standard.isDateOfBirthValid || standard.isExpiryDateValid)) {
            return standard
        }

        // Strategy 2: Anchor-based parse (locate IRQ and date signatures)
        val anchor = tryAnchorBasedParse(lines)
        if (anchor != null) {
            return anchor
        }

        return standard
    }

    private fun tryStandardParse(lines: List<String>): MrzData? {
        try {
            var line1 = lines[0]
            var line2 = lines[1]
            var line3 = if (lines.size > 2) lines[2] else "<<"

            if (line1.length < 30) line1 = line1.padEnd(30, '<')
            if (line2.length < 30) line2 = line2.padEnd(30, '<')
            if (line3.length < 30) line3 = line3.padEnd(30, '<')

            // Line 1: ID (0..1) + IRQ (2..4) + DocNo (5..13: 9 chars) + DocCheck (14) + NationalNo (15..26: 12 chars) + <<<
            val docType = line1.substring(0, 2).replace("<", "").ifEmpty { "ID" }
            val issuingCountry = line1.substring(2, 5).replace("<", "").ifEmpty { "IRQ" }
            
            // Document number can be alphanumeric (e.g. AZ9431882), preserve letters!
            val rawDocNum = line1.substring(5, 14)
            val docNum = rawDocNum.replace("<", "")
            val docNumCheckDigit = line1.substring(14, 15).firstOrNull() ?: '0'
            val isDocNumValid = MrzCheckDigitCalculator.verify(rawDocNum, docNumCheckDigit)

            val nationalNo = if (line1.length >= 27) line1.substring(15, 27).replace("<", "") else null

            // Line 2: DOB (0..5: 6 digits) + Check (6) + Sex (7: M/F) + Expiry (8..13: 6 digits) + Check (14) + IRQ (15..17)
            val rawDob = sanitizeDigitsOnly(line2.substring(0, 6))
            val dobCheckDigit = sanitizeDigitsOnly(line2.substring(6, 7)).firstOrNull() ?: '0'
            val isDobValid = MrzCheckDigitCalculator.verify(rawDob, dobCheckDigit)

            val gender = line2.substring(7, 8).replace("<", "").ifEmpty { "M" }

            val rawExpiry = sanitizeDigitsOnly(line2.substring(8, 14))
            val expiryCheckDigit = sanitizeDigitsOnly(line2.substring(14, 15)).firstOrNull() ?: '0'
            val isExpiryValid = MrzCheckDigitCalculator.verify(rawExpiry, expiryCheckDigit)

            val nationality = if (line2.length >= 18) line2.substring(15, 18).replace("<", "").ifEmpty { "IRQ" } else "IRQ"
            val compositeCheckDigit = if (line2.length >= 30) line2.substring(29, 30).firstOrNull() ?: '0' else '0'

            // Line 3: Names (e.g. <<EMAD<<<<<<<<...)
            val nameParts = line3.split("<").filter { it.isNotBlank() }
            val primaryId = nameParts.firstOrNull() ?: ""
            val secondaryId = if (nameParts.size > 1) nameParts.drop(1).joinToString(" ") else ""

            return MrzData(
                rawMrzLines = listOf(line1, line2, line3),
                documentType = docType,
                issuingCountry = issuingCountry,
                documentNumber = docNum,
                documentNumberCheckDigit = docNumCheckDigit,
                isDocumentNumberValid = isDocNumValid,
                dateOfBirth = rawDob,
                dateOfBirthCheckDigit = dobCheckDigit,
                isDateOfBirthValid = isDobValid,
                gender = gender,
                expiryDate = rawExpiry,
                expiryDateCheckDigit = expiryCheckDigit,
                isExpiryDateValid = isExpiryValid,
                nationality = nationality,
                optionalData1 = nationalNo,
                compositeCheckDigit = compositeCheckDigit,
                isCompositeValid = true,
                primaryIdentifier = primaryId,
                secondaryIdentifier = secondaryId
            )
        } catch (e: Exception) {
            return null
        }
    }

    private fun tryAnchorBasedParse(lines: List<String>): MrzData? {
        try {
            // Locate Line 1: Must contain IRQ and length >= 15
            val line1 = lines.firstOrNull { it.contains("IRQ") && it.length >= 15 } ?: return null
            val irqIndex = line1.indexOf("IRQ")
            val afterIrq = line1.substring(irqIndex + 3)
            if (afterIrq.length < 10) return null

            val rawDocNum = afterIrq.substring(0, 9)
            val docNum = rawDocNum.replace("<", "")
            val docNumCheckDigit = afterIrq.substring(9, 10).firstOrNull() ?: '0'
            val isDocNumValid = MrzCheckDigitCalculator.verify(rawDocNum, docNumCheckDigit)

            // Locate Line 2: Must contain IRQ or length >= 15 with digits
            val line2 = lines.firstOrNull { it != line1 && (it.contains("IRQ") || it.length >= 15) } ?: return null
            val rawDob = sanitizeDigitsOnly(line2.take(6))
            val dobCheckDigit = if (line2.length > 6) sanitizeDigitsOnly(line2.substring(6, 7)).firstOrNull() ?: '0' else '0'
            val isDobValid = MrzCheckDigitCalculator.verify(rawDob, dobCheckDigit)

            val rawExpiry = if (line2.length >= 14) sanitizeDigitsOnly(line2.substring(8, 14)) else ""
            val expiryCheckDigit = if (line2.length >= 15) sanitizeDigitsOnly(line2.substring(14, 15)).firstOrNull() ?: '0' else '0'
            val isExpiryValid = rawExpiry.length == 6 && MrzCheckDigitCalculator.verify(rawExpiry, expiryCheckDigit)

            // Line 3: Names
            val line3 = lines.firstOrNull { it != line1 && it != line2 } ?: ""
            val nameParts = line3.split("<").filter { it.isNotBlank() }
            val primaryId = nameParts.firstOrNull() ?: ""
            val secondaryId = if (nameParts.size > 1) nameParts.drop(1).joinToString(" ") else ""

            if (docNum.isNotEmpty() && rawDob.length == 6 && rawExpiry.length == 6) {
                return MrzData(
                    rawMrzLines = listOf(line1, line2, line3),
                    documentType = "ID",
                    issuingCountry = "IRQ",
                    documentNumber = docNum,
                    documentNumberCheckDigit = docNumCheckDigit,
                    isDocumentNumberValid = isDocNumValid,
                    dateOfBirth = rawDob,
                    dateOfBirthCheckDigit = dobCheckDigit,
                    isDateOfBirthValid = isDobValid,
                    gender = "M",
                    expiryDate = rawExpiry,
                    expiryDateCheckDigit = expiryCheckDigit,
                    isExpiryDateValid = isExpiryValid,
                    nationality = "IRQ",
                    compositeCheckDigit = '0',
                    isCompositeValid = true,
                    primaryIdentifier = primaryId,
                    secondaryIdentifier = secondaryId
                )
            }
        } catch (e: Exception) {
            // Ignore
        }
        return null
    }

    /**
     * Extracts BAC access keys from parsed MrzData.
     */
    fun extractNfcAuthKey(mrzData: MrzData): NfcAuthKey {
        return NfcAuthKey(
            documentNumber = mrzData.documentNumber,
            dateOfBirth = mrzData.dateOfBirth,
            dateOfExpiry = mrzData.expiryDate
        )
    }
}
