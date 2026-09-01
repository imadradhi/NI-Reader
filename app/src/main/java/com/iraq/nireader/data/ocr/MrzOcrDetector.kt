package com.iraq.nireader.data.ocr

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.iraq.nireader.data.model.MrzData
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Optical Character Recognition detector for Iraqi National ID MRZ using Google ML Kit.
 */
class MrzOcrDetector {

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    /**
     * Processes a Bitmap and attempts to locate and extract valid TD1 MRZ lines.
     */
    suspend fun detectMrz(bitmap: Bitmap): Result<MrzData> = suspendCancellableCoroutine { continuation ->
        val image = InputImage.fromBitmap(bitmap, 0)
        
        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                val mrzData = extractMrzFromText(visionText)
                if (mrzData != null) {
                    continuation.resume(Result.success(mrzData))
                } else {
                    continuation.resume(Result.failure(Exception("Could not detect valid 3-line TD1 MRZ in image")))
                }
            }
            .addOnFailureListener { e ->
                continuation.resume(Result.failure(e))
            }
    }

    /**
     * Scans through recognized text blocks and lines to find valid TD1 MRZ lines.
     */
    fun extractMrzFromText(visionText: Text): MrzData? {
        // Collect all lines with their vertical coordinate (top)
        data class LineWithPos(val text: String, val top: Int)

        val positionedLines = mutableListOf<LineWithPos>()

        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val cleaned = MrzParser.sanitizeLine(line.text)
                if (cleaned.isNotEmpty()) {
                    val top = line.boundingBox?.top ?: (block.boundingBox?.top ?: 0)
                    positionedLines.add(LineWithPos(cleaned, top))
                }
            }
        }

        // Sort vertically from top to bottom
        val sortedLines = positionedLines
            .sortedBy { it.top }
            .map { it.text }
            .distinct()

        // Filter candidate MRZ lines (any line with IRQ, chevrons, or length >= 14)
        val candidateLines = sortedLines.filter { line ->
            line.contains("<") || line.contains("IRQ") || line.startsWith("I") || line.startsWith("D") || line.length in 14..35
        }

        // Strategy A: Try with all candidate lines in spatial order
        if (candidateLines.size >= 2) {
            val parsed = MrzParser.parseTd1(candidateLines)
            if (parsed != null && (parsed.isDocumentNumberValid || parsed.isDateOfBirthValid || parsed.isExpiryDateValid)) {
                return parsed
            }
        }

        // Strategy B: Try sliding 3-line windows
        if (candidateLines.size >= 3) {
            for (i in 0..(candidateLines.size - 3)) {
                val threeLines = listOf(candidateLines[i], candidateLines[i + 1], candidateLines[i + 2])
                val parsed = MrzParser.parseTd1(threeLines)
                if (parsed != null && (parsed.isDocumentNumberValid || parsed.isDateOfBirthValid || parsed.isExpiryDateValid)) {
                    return parsed
                }
            }
        }

        // Strategy C: Direct parse on all sorted lines
        if (sortedLines.isNotEmpty()) {
            val parsed = MrzParser.parseTd1(sortedLines)
            if (parsed != null) return parsed
        }

        return null
    }

    fun close() {
        recognizer.close()
    }
}
