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
     * Scans through recognized text blocks and lines to find 3 consecutive lines of ~30 characters.
     */
    private fun extractMrzFromText(visionText: Text): MrzData? {
        val candidateLines = mutableListOf<String>()

        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val cleaned = MrzParser.sanitizeLine(line.text)
                // TD1 lines should have around 28-32 characters and contain '<' characters
                if (cleaned.length in 25..35 && (cleaned.contains("<") || cleaned.startsWith("I") || cleaned.contains("IRQ"))) {
                    candidateLines.add(cleaned)
                }
            }
        }

        // Try every contiguous 3-line combination
        if (candidateLines.size >= 3) {
            for (i in 0..(candidateLines.size - 3)) {
                val threeLines = listOf(candidateLines[i], candidateLines[i + 1], candidateLines[i + 2])
                val parsed = MrzParser.parseTd1(threeLines)
                if (parsed != null && (parsed.isDocumentNumberValid || parsed.isDateOfBirthValid)) {
                    return parsed
                }
            }
        }

        // Fallback: search for specific line prefixes if jumbled
        val line1 = candidateLines.firstOrNull { it.startsWith("I") && it.contains("IRQ") }
        val line2 = candidateLines.firstOrNull { it != line1 && it.length >= 28 && it.contains("IRQ") }
        val line3 = candidateLines.firstOrNull { it != line1 && it != line2 && it.contains("<<") }

        if (line1 != null && line2 != null && line3 != null) {
            val parsed = MrzParser.parseTd1(listOf(line1, line2, line3))
            if (parsed != null) return parsed
        }

        return null
    }

    fun close() {
        recognizer.close()
    }
}
