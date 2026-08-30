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
        val allLines = mutableListOf<String>()

        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val cleaned = MrzParser.sanitizeLine(line.text)
                if (cleaned.isNotEmpty()) {
                    allLines.add(cleaned)
                }
            }
            // Also split block text by newline if ML Kit merged lines
            val blockSplit = block.text.split("\n")
            for (line in blockSplit) {
                val cleaned = MrzParser.sanitizeLine(line)
                if (cleaned.isNotEmpty() && !allLines.contains(cleaned)) {
                    allLines.add(cleaned)
                }
            }
        }

        // Filter candidate MRZ lines (any line with IRQ, chevrons, or length >= 15)
        val candidateLines = allLines.filter { line ->
            line.contains("<") || line.contains("IRQ") || line.startsWith("I") || line.length in 15..35
        }

        // Strategy A: Direct parsing if 3 candidate lines exist
        if (candidateLines.size >= 3) {
            for (i in 0..(candidateLines.size - 3)) {
                val threeLines = listOf(candidateLines[i], candidateLines[i + 1], candidateLines[i + 2])
                val parsed = MrzParser.parseTd1(threeLines)
                if (parsed != null) {
                    return parsed
                }
            }
        }

        // Strategy B: Anchor-based matching among all lines
        val line1 = allLines.firstOrNull { it.contains("IRQ") && (it.startsWith("I") || it.contains("<") || it.length >= 15) }
        val line2 = allLines.firstOrNull { it != line1 && it.length >= 14 && MrzParser.sanitizeDigitsOnly(it).length >= 12 }
        val line3 = allLines.firstOrNull { it != line1 && it != line2 && (it.contains("<<") || it.contains("<")) }

        if (line1 != null && line2 != null) {
            val parsed = MrzParser.parseTd1(listOf(line1, line2, line3 ?: "HOLDER<<NAME"))
            if (parsed != null) return parsed
        }

        // Strategy C: Try full candidate lines list directly
        if (candidateLines.isNotEmpty()) {
            val parsed = MrzParser.parseTd1(candidateLines)
            if (parsed != null) return parsed
        }

        return null
    }

    fun close() {
        recognizer.close()
    }
}
