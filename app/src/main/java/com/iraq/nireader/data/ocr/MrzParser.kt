package com.iraq.nireader.data.ocr

import com.iraq.nireader.data.model.MrzData
import com.iraq.nireader.data.nfc.NfcAuthKey

/**
 * Parses and sanitizes TD1 (3 lines x 30 characters) MRZ from the Iraqi National ID.
 */
object MrzParser {

    /**
     * Cleans common OCR recognition confusion in MRZ lines.
     */
    fun sanitizeLine(line: String): String {
        return line.trim()
            .uppercase()
            .replace(" ", "")
            .replace("«", "<")
            .replace("»", "<")
            .replace("(", "<")
            .replace(")", "<")
            .replace("{", "<")
            .replace("}", "<")
            .replace("[", "<")
            .replace("]", "<")
            .replace("|", "")
            .replace("—", "")
            .replace("-", "")
    }

    /**
     * Fixes numeric field OCR misreads.
     */
    fun sanitizeNumericField(field: String): String {
        return field.replace('O', '0')
            .replace('Q', '0')
            .replace('D', '0')
            .replace('U', '0')
            .replace('I', '1')
            .replace('L', '1')
            .replace('T', '1')
            .replace('Z', '2')
            .replace('B', '8')
            .replace('S', '5')
            .replace('G', '6')
    }

    /**
     * Parses 3 sanitized lines of TD1 MRZ with multiple error-recovery strategies.
     */
    fun parseTd1(rawLines: List<String>): MrzData? {
        if (rawLines.size < 3) return null

        val lines = rawLines.map { sanitizeLine(it) }

        // Strategy 1: Standard ICAO Doc 9303 TD1 parsing with padding
        val standardParsed = tryStandardParse(lines)
        if (standardParsed != null && (standardParsed.isDocumentNumberValid || standardParsed.isDateOfBirthValid || standardParsed.isExpiryDateValid)) {
            return standardParsed
        }

        // Strategy 2: Anchor-based parsing (find IRQ and pattern signatures)
        val anchorParsed = tryAnchorBasedParse(lines)
        if (anchorParsed != null) {
            return anchorParsed
        }

        return standardParsed
    }

    private fun tryStandardParse(lines: List<String>): MrzData? {
        try {
            val line1 = lines[0].padEnd(30, '<')
            val line2 = lines[1].padEnd(30, '<')
            val line3 = lines[2].padEnd(30, '<')

            if (line1.length < 30 || line2.length < 30 || line3.length < 30) return null

            // Line 1 Parsing
            val docType = line1.substring(0, 2).replace("<", "").ifEmpty { "I" }
            val issuingCountry = line1.substring(2, 5).replace("<", "").ifEmpty { "IRQ" }
            val rawDocNum = line1.substring(5, 14)
            val docNum = sanitizeNumericField(rawDocNum).replace("<", "")
            val docNumCheckDigit = sanitizeNumericField(line1.substring(14, 15)).firstOrNull() ?: '0'
            val isDocNumValid = MrzCheckDigitCalculator.verify(rawDocNum, docNumCheckDigit)
            val optional1 = line1.substring(15, 30).replace("<", " ").trim()

            // Line 2 Parsing
            val rawDob = sanitizeNumericField(line2.substring(0, 6))
            val dobCheckDigit = sanitizeNumericField(line2.substring(6, 7)).firstOrNull() ?: '0'
            val isDobValid = MrzCheckDigitCalculator.verify(rawDob, dobCheckDigit)

            val gender = line2.substring(7, 8).replace("<", "").ifEmpty { "M" }

            val rawExpiry = sanitizeNumericField(line2.substring(8, 14))
            val expiryCheckDigit = sanitizeNumericField(line2.substring(14, 15)).firstOrNull() ?: '0'
            val isExpiryValid = MrzCheckDigitCalculator.verify(rawExpiry, expiryCheckDigit)

            val nationality = line2.substring(15, 18).replace("<", "").ifEmpty { "IRQ" }
            val optional2 = line2.substring(18, 29)

            val compositeCheckDigit = sanitizeNumericField(line2.substring(29, 30)).firstOrNull() ?: '0'
            val compositeString = line1.substring(5, 30) + line2.substring(0, 7) + line2.substring(8, 15) + optional2
            val isCompositeValid = MrzCheckDigitCalculator.verify(compositeString, compositeCheckDigit)

            // Line 3 Parsing (Names)
            val nameSplit = line3.split("<<")
            val primaryId = if (nameSplit.isNotEmpty()) nameSplit[0].replace("<", " ").trim() else ""
            val secondaryId = if (nameSplit.size > 1) nameSplit[1].replace("<", " ").trim() else ""

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
                optionalData1 = optional1.ifEmpty { null },
                compositeCheckDigit = compositeCheckDigit,
                isCompositeValid = isCompositeValid,
                primaryIdentifier = primaryId,
                secondaryIdentifier = secondaryId
            )
        } catch (e: Exception) {
            return null
        }
    }

    private fun tryAnchorBasedParse(lines: List<String>): MrzData? {
        try {
            // Find line with IRQ and document number
            val line1 = lines.firstOrNull { it.contains("IRQ") && it.length >= 14 } ?: return null
            val irqIdx = line1.indexOf("IRQ")
            val rawDocNum = if (line1.length >= irqIdx + 3 + 9) {
                line1.substring(irqIdx + 3, irqIdx + 3 + 9)
            } else {
                return null
            }
            val docNum = sanitizeNumericField(rawDocNum).replace("<", "")
            val docNumCheckDigit = if (line1.length > irqIdx + 12) sanitizeNumericField(line1.substring(irqIdx + 12, irqIdx + 13)).firstOrNull() ?: '0' else '0'
            val isDocNumValid = MrzCheckDigitCalculator.verify(rawDocNum, docNumCheckDigit)

            // Find line with Dates (DOB and Expiry)
            val line2 = lines.firstOrNull { it != line1 && sanitizeNumericField(it).length >= 14 } ?: return null
            val numericLine2 = sanitizeNumericField(line2)
            
            // Extract DOB (first 6 numeric digits)
            val dob = numericLine2.take(6)
            val dobCheck = if (numericLine2.length > 6) numericLine2[6] else '0'
            val isDobValid = MrzCheckDigitCalculator.verify(dob, dobCheck)

            // Extract Expiry (digits 8..14)
            val exp = if (numericLine2.length >= 14) numericLine2.substring(8, 14) else ""
            val expCheck = if (numericLine2.length > 14) numericLine2[14] else '0'
            val isExpValid = if (exp.length == 6) MrzCheckDigitCalculator.verify(exp, expCheck) else false

            // Line 3 Names
            val line3 = lines.firstOrNull { it != line1 && it != line2 } ?: ""
            val nameSplit = line3.split("<<")
            val primaryId = if (nameSplit.isNotEmpty()) nameSplit[0].replace("<", " ").trim() else ""
            val secondaryId = if (nameSplit.size > 1) nameSplit[1].replace("<", " ").trim() else ""

            if (docNum.isNotEmpty() && dob.length == 6 && exp.length == 6) {
                return MrzData(
                    rawMrzLines = listOf(line1, line2, line3),
                    documentType = "I",
                    issuingCountry = "IRQ",
                    documentNumber = docNum,
                    documentNumberCheckDigit = docNumCheckDigit,
                    isDocumentNumberValid = isDocNumValid,
                    dateOfBirth = dob,
                    dateOfBirthCheckDigit = dobCheck,
                    isDateOfBirthValid = isDobValid,
                    gender = "M",
                    expiryDate = exp,
                    expiryDateCheckDigit = expCheck,
                    isExpiryDateValid = isExpValid,
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
