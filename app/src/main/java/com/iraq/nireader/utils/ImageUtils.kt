package com.iraq.nireader.utils

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.Arrays

object ImageUtils {

    /**
     * Decodes an input stream containing facial image bytes (ISO 19794-5 or CBEFF standard) to a Bitmap.
     */
    fun decodeFaceImageStream(inputStream: InputStream, imageLength: Int): Bitmap? {
        return try {
            val bytes = ByteArray(imageLength)
            var totalRead = 0
            while (totalRead < imageLength) {
                val read = inputStream.read(bytes, totalRead, imageLength - totalRead)
                if (read == -1) break
                totalRead += read
            }
            decodeImageBytes(bytes)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Decodes raw bytes into Bitmap, handling standard formats (JPEG, PNG, WebP).
     */
    fun decodeImageBytes(bytes: ByteArray): Bitmap? {
        return try {
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Converts a Bitmap into a Base64 encoded JPEG string.
     */
    fun bitmapToBase64(bitmap: Bitmap?, quality: Int = 85): String? {
        if (bitmap == null) return null
        return try {
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
            val byteArray = outputStream.toByteArray()
            Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Rotates a Bitmap if needed (e.g. from camera orientation).
     */
    fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        if (degrees == 0f) return bitmap
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
