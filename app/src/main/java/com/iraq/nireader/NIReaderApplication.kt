package com.iraq.nireader

import android.app.Application
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.security.Security

/**
 * Application class for Iraqi National ID Reader.
 * Registers BouncyCastle crypto provider required by JMRTD / SCUBA for BAC & PACE authentication.
 */
class NIReaderApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        setupSecurityProvider()
    }

    private fun setupSecurityProvider() {
        // Ensure BouncyCastle provider is registered at top priority for ICAO 9303 cryptography
        val existing = Security.getProvider(BouncyCastleProvider.PROVIDER_NAME)
        if (existing != null) {
            Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME)
        }
        Security.insertProviderAt(BouncyCastleProvider(), 1)
    }
}
