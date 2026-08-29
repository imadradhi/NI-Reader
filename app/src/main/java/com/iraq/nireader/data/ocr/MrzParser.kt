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
            .replace("(", "<")
            .replace("{", "<")
            .replace("[", "<")
    }

    /**
     * Fixes number field OCR misreads ('O' -> '0', 'I' -> '1', 'Z' -> '2', 'B' -> '8', 'S' -> '5').
     */
    fun sanitizeNumericField(field: String): String {
        return field.replace('O', '0')
            .replace('Q', '0')
            .replace('D', '0')
            .replace('I', '1')
            .replace('L', '1')
            .replace('Z', '2')
            .replace('B', '8')
            .replace('S', '5')
    }

    /**
     * Parses 3 sanitized lines of TD1 MRZ.
     */
    fun parseTd1(lines: List<String>): MrzData? {
        if (lines.size < 3) return null

        val line1 = sanitizeLine(lines[0]).padEnd(30, '<')
        val line2 = sanitizeLine(lines[1]).padEnd(30, '<')
        val line3 = sanitizeLine(lines[2]).padEnd(30, '<')

        if (line1.length < 30 || line2.length < 30 || line3.length < 30) return null

        try {
            // Line 1 Parsing
            val docType = line1.substring(0, 2).replace("<", "")
            val issuingCountry = line1.substring(2, 5).replace("<", "")
            val rawDocNum = line1.substring(5, 14)
            val docNum = sanitizeNumericField(rawDocNum).replace("<", "")
            val docNumCheckDigit = sanitizeNumericField(line1.substring(14, 15))[0]
            val isDocNumValid = MrzCheckDigitCalculator.verify(rawDocNum, docNumCheckDigit)
            val optional1 = line1.substring(15, 30).replace("<", " ").trim()

            // Line 2 Parsing
            val rawDob = sanitizeNumericField(line2.substring(0, 6))
            val dobCheckDigit = sanitizeNumericField(line2.substring(6, 7))[0]
            val isDobValid = MrzCheckDigitCalculator.verify(rawDob, dobCheckDigit)

            val gender = line2.substring(7, 8).replace("<", "")

            val rawExpiry = sanitizeNumericField(line2.substring(8, 14))
            val expiryCheckDigit = sanitizeNumericField(line2.substring(14, 15))[0]
            val isExpiryValid = MrzCheckDigitCalculator.verify(rawExpiry, expiryCheckDigit)

            val nationality = line2.substring(15, 18).replace("<", "")
            val optional2 = line2.substring(18, 29)

            val compositeCheckDigit = sanitizeNumericField(line2.substring(29, 30))[0]
            
            // Composite verification string per ICAO Doc 9303 Part 5 (TD1)
            val compositeString = line1.substring(5, 30) + line2.substring(0, 7) + line2.substring(8, 15) + optional2
            val isCompositeValid = MrzCheckDigitCalculator.verify(compositeString, compositeCheckDigit)

            // Line 3 Parsing (Names)
            val namesPart = line3.replace("<", " ").trim()
            val nameSplit = line3.split("<<")
            val primaryId = if (nameSplit.isNotEmpty()) nameSplit[0].replace("<", " ").trim() else ""
            val secondaryId = if (nameSplit.size > 1) nameSplit[1].replace("<", " ").trim() else ""

            return MrzData(
                rawMrzLines = listOf(line1, line2, line3),
                documentType = if (docType.isNotEmpty()) docType else "I",
                issuingCountry = if (issuingCountry.isNotEmpty()) issuingCountry else "IRQ",
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
                nationality = if (nationality.isNotEmpty()) nationality else "IRQ",
                optionalData1 = optional1.ifEmpty { null },
                compositeCheckDigit = compositeCheckDigit,
                isCompositeValid = isCompositeValid,
                primaryIdentifier = primaryId,
                secondaryIdentifier = secondaryId
            )
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
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
