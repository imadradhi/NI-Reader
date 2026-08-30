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
    fun testRealIraqiIdCardParsing() {
        // Real Iraqi ID card sample from physical card photo
        val line1 = "IDIRQAZ94318824198405252409<<<"
        val line2 = "8408299M3112113IRQ<<<<<<<<<<<9"
        val line3 = "<<EMAD<<<<<<<<<<<<<<<<<<<<<<<"

        val mrz = MrzParser.parseTd1(listOf(line1, line2, line3))
        assertNotNull(mrz)
        assertEquals("AZ9431882", mrz!!.documentNumber)
        assertEquals('4', mrz.documentNumberCheckDigit)
        assertTrue(mrz.isDocumentNumberValid)

        assertEquals("840829", mrz.dateOfBirth)
        assertEquals('9', mrz.dateOfBirthCheckDigit)
        assertTrue(mrz.isDateOfBirthValid)
        assertEquals("1984-08-29", mrz.formattedDob())

        assertEquals("311211", mrz.expiryDate)
        assertEquals('3', mrz.expiryDateCheckDigit)
        assertTrue(mrz.isExpiryDateValid)
        assertEquals("2031-12-11", mrz.formattedExpiry())

        assertEquals("M", mrz.gender)
        assertEquals("IRQ", mrz.issuingCountry)
        assertEquals("198405252409", mrz.optionalData1)
        assertEquals("EMAD", mrz.primaryIdentifier)

        // BAC Key derived from this MRZ
        val authKey = MrzParser.extractNfcAuthKey(mrz)
        val bacSpec = authKey.toBacKeySpec()
        assertEquals("AZ9431882", bacSpec.documentNumber)
        assertEquals("840829", bacSpec.dateOfBirth)
        assertEquals("311211", bacSpec.dateOfExpiry)
    }

    @Test
    fun testSixtyCharacterCoreMrzParsing() {
        // Continuous 60-character stream (Line 1: 30 chars + Line 2: 30 chars)
        val continuous60 = "IDIRQAZ94318824198405252409<<<8408299M3112113IRQ<<<<<<<<<<<9"
        assertEquals(60, continuous60.length)

        val mrzFromContinuous = MrzParser.parseTd1(listOf(continuous60))
        assertNotNull(mrzFromContinuous)
        assertEquals("AZ9431882", mrzFromContinuous!!.documentNumber)
        assertEquals("840829", mrzFromContinuous.dateOfBirth)
        assertEquals("311211", mrzFromContinuous.expiryDate)
        assertTrue(mrzFromContinuous.isDocumentNumberValid)
        assertTrue(mrzFromContinuous.isDateOfBirthValid)
        assertTrue(mrzFromContinuous.isExpiryDateValid)

        // 2 separate 30-character lines (60 characters total)
        val l1 = "IDIRQAZ94318824198405252409<<<"
        val l2 = "8408299M3112113IRQ<<<<<<<<<<<9"
        val mrzFrom2Lines = MrzParser.parseTd1(listOf(l1, l2))
        assertNotNull(mrzFrom2Lines)
        assertEquals("AZ9431882", mrzFrom2Lines!!.documentNumber)
        assertEquals("840829", mrzFrom2Lines.dateOfBirth)
        assertEquals("311211", mrzFrom2Lines.expiryDate)
    }
}
