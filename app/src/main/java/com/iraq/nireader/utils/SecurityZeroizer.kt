package com.iraq.nireader.utils

import android.graphics.Bitmap
import java.util.Arrays

/**
 * Utility for in-place memory sanitization and zeroization.
 * Implements the project security rule: No permanent storage, immediate memory wipe after transmission.
 */
object SecurityZeroizer {

    /**
     * Wipes byte arrays in memory by overwriting with zeros.
     */
    fun zeroize(byteArray: ByteArray?) {
        if (byteArray != null) {
            Arrays.fill(byteArray, 0.toByte())
        }
    }

    /**
     * Wipes char arrays (e.g. passwords, PINs, keys) in memory.
     */
    fun zeroize(charArray: CharArray?) {
        if (charArray != null) {
            Arrays.fill(charArray, '\u0000')
        }
    }

    /**
     * Safely recycles and eliminates Bitmap objects.
     */
    fun wipeBitmap(bitmap: Bitmap?) {
        if (bitmap != null && !bitmap.isRecycled) {
            try {
                bitmap.recycle()
            } catch (e: Exception) {
                // Ignore recycling exceptions
            }
        }
    }

    /**
     * Explicit garbage collection suggestion after clearing references.
     */
    fun requestMemoryPurge() {
        System.gc()
    }
}
