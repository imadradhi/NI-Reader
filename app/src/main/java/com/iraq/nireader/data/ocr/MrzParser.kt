package com.iraq.nireader.data.ocr

import com.iraq.nireader.data.model.MrzData
import com.iraq.nireader.data.nfc.NfcAuthKey

/**
 * Parses, sanitizes, and auto-heals TD1 (3 lines x 30 characters) MRZ from the Iraqi National ID.
 * Standard TD1 Format:
 * Line 1: IDIRQ + DocNo(9 chars: e.g. AZ9431882) + Check(1) + NationalNo(12) + <<<
 * Line 2: DOB(6: YYMMDD) + Check(1) + Sex(1: M/F) + Expiry(6: YYMMDD) + Check(1) + IRQ + <<<<<<<<< + CompositeCheck(1)
 * Line 3: << + First/Full Name + <<<<<<<<<<<<<<<
 */
object MrzParser {

    private val CONFUSION_MAP = mapOf(
        'O' to listOf('0', 'Q', 'D', 'U'),
        '0' to listOf('O', 'Q', 'D', 'U'),
        'I' to listOf('1', 'L', 'T', 'J'),
        '1' to listOf('I', 'L', 'T', 'J'),
        'B' to listOf('8', '3'),
        '8' to listOf('B', '3'),
        'S' to listOf('5'),
        '5' to listOf('S'),
        'Z' to listOf('2'),
        '2' to listOf('Z'),
        'G' to listOf('6'),
        '6' to listOf('G')
    )

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
     * Auto-heals numeric fields (like DOB or Expiry) by testing common OCR substitutions against the check digit.
     */
    fun autoHealNumericField(rawField: String, rawCheckDigit: Char): Pair<String, Char> {
        val sanitizedField = sanitizeDigitsOnly(rawField)
        val sanitizedCheck = sanitizeDigitsOnly(rawCheckDigit.toString()).firstOrNull() ?: '0'

        // Check if already valid
        if (sanitizedField.length == 6 && MrzCheckDigitCalculator.verify(sanitizedField, sanitizedCheck)) {
            return Pair(sanitizedField, sanitizedCheck)
        }

        // Try single-character mutations strictly from CONFUSION_MAP
        val chars = sanitizedField.toCharArray()
        for (i in chars.indices) {
            val original = chars[i]
            val alternates = CONFUSION_MAP[original] ?: emptyList()
            for (alt in alternates) {
                if (alt.isDigit() && alt != original) {
                    chars[i] = alt
                    val candidate = String(chars)
                    if (candidate.length == 6 && MrzCheckDigitCalculator.verify(candidate, sanitizedCheck)) {
                        return Pair(candidate, sanitizedCheck)
                    }
                }
            }
            chars[i] = original
        }

        // If field was correct but check digit was misread or different
        return Pair(sanitizedField, sanitizedCheck)
    }

    /**
     * Auto-heals alphanumeric fields (like Document Number) against the check digit.
     */
    fun autoHealAlphanumericField(rawField: String, rawCheckDigit: Char): Pair<String, Char> {
        val cleanField = rawField.uppercase().replace("<", "").trim()
        val cleanCheck = sanitizeDigitsOnly(rawCheckDigit.toString()).firstOrNull() ?: '0'

        if (cleanField.isNotEmpty() && MrzCheckDigitCalculator.verify(cleanField, cleanCheck)) {
            return Pair(cleanField, cleanCheck)
        }

        // Try single-character OCR substitution from CONFUSION_MAP
        val chars = cleanField.toCharArray()
        for (i in chars.indices) {
            val original = chars[i]
            val alternates = CONFUSION_MAP[original] ?: emptyList()
            for (alt in alternates) {
                chars[i] = alt
                val candidate = String(chars)
                if (MrzCheckDigitCalculator.verify(candidate, cleanCheck)) {
                    return Pair(candidate, cleanCheck)
                }
            }
            chars[i] = original
        }

        return Pair(cleanField, cleanCheck)
    }

    /**
     * Parses TD1 MRZ from the Iraqi National ID.
     */
    fun parseTd1(rawLines: List<String>): MrzData? {
        if (rawLines.isEmpty()) return null

        var lines = rawLines.map { sanitizeLine(it) }.filter { it.isNotBlank() }

        // If passed continuous stream of 60+ chars
        if (lines.size == 1 && lines[0].length >= 60) {
            val fullText = lines[0]
            val l1 = fullText.substring(0, 30)
            val l2 = fullText.substring(30, 60)
            val l3 = if (fullText.length >= 90) fullText.substring(60, 90) else "<<"
            lines = listOf(l1, l2, l3)
        }

        if (lines.size < 2) return null

        // Strategy 1: Standard positional parse
        val standard = tryStandardParse(lines)
        if (standard != null && (standard.isDocumentNumberValid || standard.isDateOfBirthValid || standard.isExpiryDateValid)) {
            return standard
        }

        // Strategy 2: Anchor-based parse (Locates Line 1 via ID/IRQ and Line 2 via dates & IRQ)
        val anchor = tryAnchorBasedParse(lines)
        if (anchor != null) {
            return anchor
        }

        return standard
    }

    private fun tryStandardParse(lines: List<String>): MrzData? {
        try {
            var line1 = lines[0].trimStart('<')
            var line2 = lines[1].trimStart('<')
            var line3 = if (lines.size > 2) lines[2] else "<<"

            if (line1.length < 30) line1 = line1.padEnd(30, '<')
            if (line2.length < 30) line2 = line2.padEnd(30, '<')
            if (line3.length < 30) line3 = line3.padEnd(30, '<')

            // Line 1: Type (0..1) + Country (2..4) + DocNo (9 chars) + DocCheck (1) + NationalNo (12)
            val docType = if (line1.startsWith("ID")) "ID" else "I"
            val issuingCountry = "IRQ"

            val irqIdx1 = line1.indexOf("IRQ")
            val docStart = if (irqIdx1 >= 0) irqIdx1 + 3 else 5
            val rawDocNum = if (line1.length >= docStart + 9) line1.substring(docStart, docStart + 9) else line1.take(9)
            val rawDocCheck = if (line1.length >= docStart + 10) line1[docStart + 9] else '0'
            val (docNum, docNumCheckDigit) = autoHealAlphanumericField(rawDocNum, rawDocCheck)
            val isDocNumValid = MrzCheckDigitCalculator.verify(docNum, docNumCheckDigit)

            val natStart = docStart + 10
            val nationalNo = if (line1.length >= natStart + 12) line1.substring(natStart, natStart + 12).replace("<", "").ifEmpty { null } else null

            // Line 2: DOB (0..5: 6 digits) + Check (6) + Sex (7) + Expiry (8..13: 6 digits) + Check (14) + IRQ (15..17)
            val rawDob = line2.take(6)
            val rawDobCheck = if (line2.length >= 7) line2[6] else '0'
            val (dob, dobCheckDigit) = autoHealNumericField(rawDob, rawDobCheck)
            val isDobValid = MrzCheckDigitCalculator.verify(dob, dobCheckDigit)

            val gender = if (line2.length >= 8) line2.substring(7, 8).replace("<", "").ifEmpty { "M" } else "M"

            val rawExpiry = if (line2.length >= 14) line2.substring(8, 14) else ""
            val rawExpiryCheck = if (line2.length >= 15) line2[14] else '0'
            val (expiry, expiryCheckDigit) = autoHealNumericField(rawExpiry, rawExpiryCheck)
            val isExpiryValid = MrzCheckDigitCalculator.verify(expiry, expiryCheckDigit)

            val nationality = if (line2.length >= 18) line2.substring(15, 18).replace("<", "").ifEmpty { "IRQ" } else "IRQ"
            val compositeCheckDigit = if (line2.length >= 30) line2.substring(29, 30).firstOrNull() ?: '0' else '0'

            // Line 3: Holder Names
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
                dateOfBirth = dob,
                dateOfBirthCheckDigit = dobCheckDigit,
                isDateOfBirthValid = isDobValid,
                gender = gender,
                expiryDate = expiry,
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
            // Line 1 Candidate: Starts with I or ID or contains IRQ followed by document number
            val line1 = lines.firstOrNull { l ->
                (l.startsWith("I") || l.startsWith("D")) && (l.contains("IRQ") || l.length >= 15) &&
                        !l.contains(Regex("^[0-9]{6}"))
            } ?: lines.firstOrNull { it.contains("IRQ") && !it.contains(Regex("^[0-9]{6}")) }

            // Line 2 Candidate: Starts with 6 digits (DOB) or contains gender (M/F)
            val line2 = lines.firstOrNull { l ->
                l != line1 && (l.matches(Regex("^[0-9OQDUILTBZSG]{6}.*")) || l.contains("M") || l.contains("F")) &&
                        l.length >= 15
            } ?: lines.firstOrNull { it != line1 && it.length >= 15 }

            if (line1 == null || line2 == null) return null

            // Extract Line 1 fields: Find IRQ anchor
            val irqIdx = line1.indexOf("IRQ")
            val docPart = if (irqIdx >= 0 && line1.length >= irqIdx + 3 + 10) {
                line1.substring(irqIdx + 3)
            } else if (line1.length >= 15) {
                line1.drop(5)
            } else {
                return null
            }

            val rawDocNum = docPart.take(9)
            val rawDocCheck = if (docPart.length >= 10) docPart[9] else '0'
            val (docNum, docCheck) = autoHealAlphanumericField(rawDocNum, rawDocCheck)
            val isDocValid = MrzCheckDigitCalculator.verify(docNum, docCheck)

            val nationalNo = if (docPart.length >= 22) docPart.substring(10, 22).replace("<", "").ifEmpty { null } else null

            // Extract Line 2 fields: DOB (0..5), Check (6), Sex (7), Expiry (8..13), Check (14)
            val rawDob = line2.take(6)
            val rawDobCheck = if (line2.length >= 7) line2[6] else '0'
            val (dob, dobCheck) = autoHealNumericField(rawDob, rawDobCheck)
            val isDobValid = MrzCheckDigitCalculator.verify(dob, dobCheck)

            val gender = if (line2.length >= 8) line2.substring(7, 8).replace("<", "").ifEmpty { "M" } else "M"

            val rawExp = if (line2.length >= 14) line2.substring(8, 14) else ""
            val rawExpCheck = if (line2.length >= 15) line2[14] else '0'
            val (exp, expCheck) = autoHealNumericField(rawExp, rawExpCheck)
            val isExpValid = exp.length == 6 && MrzCheckDigitCalculator.verify(exp, expCheck)

            // Line 3 Names
            val line3 = lines.firstOrNull { it != line1 && it != line2 } ?: ""
            val nameParts = line3.split("<").filter { it.isNotBlank() }
            val primaryId = nameParts.firstOrNull() ?: ""
            val secondaryId = if (nameParts.size > 1) nameParts.drop(1).joinToString(" ") else ""

            if (docNum.isNotEmpty() && dob.length == 6 && exp.length == 6) {
                return MrzData(
                    rawMrzLines = listOf(line1, line2, line3),
                    documentType = "ID",
                    issuingCountry = "IRQ",
                    documentNumber = docNum,
                    documentNumberCheckDigit = docCheck,
                    isDocumentNumberValid = isDocValid,
                    dateOfBirth = dob,
                    dateOfBirthCheckDigit = dobCheck,
                    isDateOfBirthValid = isDobValid,
                    gender = gender,
                    expiryDate = exp,
                    expiryDateCheckDigit = expCheck,
                    isExpiryDateValid = isExpValid,
                    nationality = "IRQ",
                    optionalData1 = nationalNo,
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
