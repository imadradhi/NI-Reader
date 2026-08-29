package com.iraq.nireader.utils

object ByteUtils {
    private val HEX_CHARS = "0123456789ABCDEF".toCharArray()

    fun toHexString(bytes: ByteArray): String {
        val result = StringBuilder(bytes.size * 2)
        for (byte in bytes) {
            val i = byte.toInt() and 0xFF
            result.append(HEX_CHARS[i ushr 4])
            result.append(HEX_CHARS[i and 0x0F])
        }
        return result.toString()
    }
}
