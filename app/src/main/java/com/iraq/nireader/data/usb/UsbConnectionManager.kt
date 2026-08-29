package com.iraq.nireader.data.usb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.os.BatteryManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class UsbState {
    CONNECTED,
    DISCONNECTED,
    UNKNOWN
}

/**
 * Manages detection of USB cable connection and detachment from PC.
 */
class UsbConnectionManager(private val context: Context) {

    private val _usbState = MutableStateFlow(UsbState.UNKNOWN)
    val usbState: StateFlow<UsbState> = _usbState.asStateFlow()

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return

            when (intent.action) {
                "android.hardware.usb.action.USB_STATE" -> {
                    val connected = intent.getBooleanExtra("connected", false)
                    _usbState.value = if (connected) UsbState.CONNECTED else UsbState.DISCONNECTED
                }
                UsbManager.ACTION_USB_ACCESSORY_ATTACHED -> {
                    _usbState.value = UsbState.CONNECTED
                }
                UsbManager.ACTION_USB_ACCESSORY_DETACHED -> {
                    _usbState.value = UsbState.DISCONNECTED
                }
                Intent.ACTION_POWER_CONNECTED -> {
                    val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
                        context?.registerReceiver(null, filter)
                    }
                    val chargePlug = batteryStatus?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1
                    val usbCharge = chargePlug == BatteryManager.BATTERY_PLUGGED_USB
                    if (usbCharge) {
                        _usbState.value = UsbState.CONNECTED
                    }
                }
                Intent.ACTION_POWER_DISCONNECTED -> {
                    _usbState.value = UsbState.DISCONNECTED
                }
            }
        }
    }

    fun startListening() {
        val filter = IntentFilter().apply {
            addAction("android.hardware.usb.action.USB_STATE")
            addAction(UsbManager.ACTION_USB_ACCESSORY_ATTACHED)
            addAction(UsbManager.ACTION_USB_ACCESSORY_DETACHED)
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        context.registerReceiver(usbReceiver, filter)
    }

    fun stopListening() {
        try {
            context.unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            // Ignore unregister exceptions
        }
    }
}
