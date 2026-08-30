package com.iraq.nireader

import com.iraq.nireader.data.nfc.NfcAuthKey
import com.iraq.nireader.data.ocr.MrzCheckDigitCalculator
import com.iraq.nireader.data.ocr.MrzParser
import org.junit.Assert.*
import org.junit.Test

class MrzAndNfcUnitTest {

    @Test
    fun testIraqiIdCheckDigitCalculation() {
        // Test standard 7-3-1 weight check digit algorithm
        // 9-digit document number
        val docNum = "123456789"
        val checkDigit = MrzCheckDigitCalculator.calculateCheckDigit(docNum)
        assertTrue(MrzCheckDigitCalculator.verify(docNum, checkDigit))

        // 6-digit DOB (950101)
        val dob = "950101"
        val dobCheck = MrzCheckDigitCalculator.calculateCheckDigit(dob)
        assertTrue(MrzCheckDigitCalculator.verify(dob, dobCheck))

        // 6-digit Expiry (300101)
        val exp = "300101"
        val expCheck = MrzCheckDigitCalculator.calculateCheckDigit(exp)
        assertTrue(MrzCheckDigitCalculator.verify(exp, expCheck))
    }

    @Test
    fun testIraqiIdTd1Parsing() {
        // Typical 3-line TD1 MRZ on back of Iraqi National ID
        val line1 = "I<IRQ1234567897<<<<<<<<<<<<<<<"
        val line2 = "9001014M3001018IRQ<<<<<<<<<<<2"
        val line3 = "KADHIMI<<AHMED<<<<<<<<<<<<<<<<"

        val mrz = MrzParser.parseTd1(listOf(line1, line2, line3))
        assertNotNull(mrz)
        assertEquals("123456789", mrz!!.documentNumber)
        assertEquals("900101", mrz.dateOfBirth)
        assertEquals("300101", mrz.expiryDate)
        assertEquals("IRQ", mrz.issuingCountry)
        assertEquals("KADHIMI", mrz.primaryIdentifier)
        assertEquals("AHMED", mrz.secondaryIdentifier)
    }

    @Test
    fun testIraqiIdTd1ParsingWithOcrNoise() {
        // Simulating ML Kit OCR noise (brackets, spaces, OCR character substitution)
        val line1 = "«I<IRQ1234567897«««««««««««««««"
        val line2 = "9OO1O14M3OO1O18IRQ«««««««««««2"
        val line3 = "KADHIMI<<AHMED««««««««««««««««"

        val mrz = MrzParser.parseTd1(listOf(line1, line2, line3))
        assertNotNull(mrz)
        assertEquals("123456789", mrz!!.documentNumber)
        assertEquals("900101", mrz.dateOfBirth)
        assertEquals("300101", mrz.expiryDate)
    }

    @Test
    fun testNfcAuthKeyBacKeySpecStrictFormatting() {
        val authKey = NfcAuthKey(
            documentNumber = "123456789",
            dateOfBirth = "900101",
            dateOfExpiry = "300101"
        )
        val spec = authKey.toBacKeySpec()
        assertEquals("123456789", spec.documentNumber)
        assertEquals("900101", spec.dateOfBirth)
        assertEquals("300101", spec.dateOfExpiry)

        // Padded 8-character document number
        val authKey8 = NfcAuthKey(
            documentNumber = "12345678",
            dateOfBirth = "1990-01-01",
            dateOfExpiry = "2030-01-01"
        )
        val spec8 = authKey8.toBacKeySpec()
        assertEquals("12345678<", spec8.documentNumber)
        assertEquals("900101", spec8.dateOfBirth)
        assertEquals("300101", spec8.dateOfExpiry)
    }
}
