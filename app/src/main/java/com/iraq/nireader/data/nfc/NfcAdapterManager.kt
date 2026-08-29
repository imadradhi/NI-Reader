package com.iraq.nireader.data.nfc

import android.app.Activity
import android.content.Context
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle

/**
 * Manages NFC hardware adapter state, reader mode callbacks, and availability checks.
 */
class NfcAdapterManager(private val context: Context) {

    private val nfcAdapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(context)

    val isNfcSupported: Boolean
        get() = nfcAdapter != null

    val isNfcEnabled: Boolean
        get() = nfcAdapter?.isEnabled == true

    /**
     * Enables ReaderMode with optimized flags for eMRTD smart card reading.
     */
    fun enableReaderMode(activity: Activity, onTagDiscovered: (Tag) -> Unit) {
        if (nfcAdapter == null || !nfcAdapter.isEnabled) return

        val flags = NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

        val options = Bundle().apply {
            putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 500)
        }

        nfcAdapter.enableReaderMode(activity, { tag ->
            activity.runOnUiThread {
                onTagDiscovered(tag)
            }
        }, flags, options)
    }

    /**
     * Disables ReaderMode when Activity pauses or finishes.
     */
    fun disableReaderMode(activity: Activity) {
        if (nfcAdapter != null && nfcAdapter.isEnabled) {
            try {
                nfcAdapter.disableReaderMode(activity)
            } catch (e: Exception) {
                // Ignore lifecycle exception
            }
        }
    }
}
