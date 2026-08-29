package com.iraq.nireader.data.nfc

import android.graphics.Bitmap
import android.nfc.Tag
import android.nfc.tech.IsoDep
import com.iraq.nireader.data.model.NfcData
import com.iraq.nireader.utils.ByteUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import net.sf.scuba.smartcards.CardFileInputStream
import net.sf.scuba.smartcards.CardService
import org.jmrtd.PassportService
import org.jmrtd.lds.CardAccessFile
import org.jmrtd.lds.PACEInfo
import org.jmrtd.lds.SODFile
import org.jmrtd.lds.icao.DG11File
import org.jmrtd.lds.icao.DG1File
import org.jmrtd.lds.icao.DG2File
import java.io.InputStream
import java.security.spec.AlgorithmParameterSpec

/**
 * Core NFC Reader Engine for the Iraqi National ID card.
 * Implements ICAO Doc 9303 specification for eMRTD authentication (PACE / BAC)
 * and Data Group extraction (DG1, DG2, DG11, DG13, SOD).
 */
class IraqiIdNfcReader {

    companion object {
        private const val ISO_DEP_TIMEOUT_MS = 10000
    }

    /**
     * Reads the Iraqi National ID card from an IsoDep NFC Tag.
     * Emits continuous progress states via Kotlin Flow.
     */
    fun readCard(tag: Tag, authKey: NfcAuthKey): Flow<NfcReadStatus> = flow {
        val startTime = System.currentTimeMillis()
        val isoDep = IsoDep.get(tag)

        if (isoDep == null) {
            emit(NfcReadStatus.Error("Tag does not support ISO/IEC 14443-4 (IsoDep) protocol"))
            return@flow
        }

        var passportService: PassportService? = null
        try {
            isoDep.timeout = ISO_DEP_TIMEOUT_MS
            isoDep.connect()

            val isTypeA = isoDep.historicalBytes != null
            val isTypeB = isoDep.hiLayerResponse != null
            val isoType = when {
                isTypeA -> "ISO/IEC 14443-4 (Type A)"
                isTypeB -> "ISO/IEC 14443-4 (Type B)"
                else -> "ISO/IEC 14443-4"
            }

            val uidHex = ByteUtils.toHexString(tag.id)
            val historicalBytes = isoDep.historicalBytes ?: isoDep.hiLayerResponse
            val historicalHex = historicalBytes?.let { ByteUtils.toHexString(it) }
            val cardSummary = "$isoType | UID: $uidHex${if (historicalHex != null) " | ATS/ATTRIB: $historicalHex" else ""}"
            
            emit(NfcReadStatus.CardDiscovered(historicalBytes = cardSummary, protocol = isoType))

            val maxTranceiveLength = if (isoDep.maxTransceiveLength > 0) {
                minOf(isoDep.maxTransceiveLength, PassportService.NORMAL_MAX_TRANCEIVE_LENGTH)
            } else {
                PassportService.NORMAL_MAX_TRANCEIVE_LENGTH
            }

            val cardService = CardService.getInstance(isoDep)
            passportService = PassportService(
                cardService,
                maxTranceiveLength,
                PassportService.DEFAULT_MAX_BLOCKSIZE,
                isoDep.isExtendedLengthApduSupported,
                false
            )
            passportService.open()

            var authProtocol = "BAC"
            var isPaceSucceeded = false

            // 1. Check for PACE (Password Authenticated Connection Establishment)
            try {
                val cardAccessFile = CardAccessFile(passportService.getInputStream(PassportService.EF_CARD_ACCESS))
                val securityInfos = cardAccessFile.securityInfos
                if (securityInfos != null && securityInfos.isNotEmpty()) {
                    for (secInfo in securityInfos) {
                        if (secInfo is PACEInfo) {
                            try {
                                emit(NfcReadStatus.Authenticating("PACE (${secInfo.protocolOIDString})"))
                                val bacKeySpec = authKey.toBacKeySpec()
                                passportService.doPACE(
                                    bacKeySpec,
                                    secInfo.objectIdentifier,
                                    PACEInfo.toParameterSpec(secInfo.parameterId),
                                    null
                                )
                                authProtocol = "PACE"
                                isPaceSucceeded = true
                                break
                            } catch (e: Exception) {
                                // Try next PACE or fallback to BAC
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                // CardAccess not present or not readable, fallback to standard BAC
            }


            // 2. Perform BAC if PACE was not executed or failed
            if (!isPaceSucceeded) {
                emit(NfcReadStatus.Authenticating("BAC"))
                val bacKey = authKey.toBacKeySpec()
                passportService.sendSelectApplet(false)
                passportService.doBAC(bacKey)
                authProtocol = "BAC"
            }

            // 3. Read Data Groups (DG1, DG2, DG11, DG13, SOD)
            val totalDgs = 5
            var currentStep = 1

            // DG1 - MRZ Info
            emit(NfcReadStatus.ReadingDataGroup("DG1 (MRZ Data)", currentStep++, totalDgs))
            val dg1In: InputStream = passportService.getInputStream(PassportService.EF_DG1)
            val dg1File = DG1File(dg1In)
            val dg1Mrz = NfcDataGroupParser.parseDg1(dg1File)

            // DG2 - Facial Biometric Image
            emit(NfcReadStatus.ReadingDataGroup("DG2 (Biometric Face Photo)", currentStep++, totalDgs))
            var faceBitmap: Bitmap? = null
            var faceBase64: String? = null
            var dg2Present = false
            try {
                val dg2In: InputStream = passportService.getInputStream(PassportService.EF_DG2)
                val dg2File = DG2File(dg2In)
                val (bmp, b64) = NfcDataGroupParser.parseDg2FaceImage(dg2File)
                faceBitmap = bmp
                faceBase64 = b64
                dg2Present = (bmp != null)
            } catch (e: Exception) {
                // DG2 read error or protected
            }

            // DG11 - Personal details (Optional)
            emit(NfcReadStatus.ReadingDataGroup("DG11 (Personal Details)", currentStep++, totalDgs))
            var dg11Details = com.iraq.nireader.data.model.Dg11PersonalDetails()
            try {
                val dg11In: InputStream = passportService.getInputStream(PassportService.EF_DG11)
                val dg11File = DG11File(dg11In)
                dg11Details = NfcDataGroupParser.parseDg11(dg11File)
            } catch (e: Exception) {
                // Optional DG11 may not exist on some card profiles
            }

            // DG13 - Optional National Security Fields
            emit(NfcReadStatus.ReadingDataGroup("DG13 (National Security Data)", currentStep++, totalDgs))
            val dg13Map = mutableMapOf<String, String>()
            try {
                val dg13In: InputStream = passportService.getInputStream(PassportService.EF_DG13)
                // DG13 format can be country specific ASN.1/TLV
                dg13Map["status"] = "Present"
            } catch (e: Exception) {
                // DG13 not present or requires EAC
            }

            // SOD - Security Object File (Document Signatures)
            emit(NfcReadStatus.ReadingDataGroup("SOD (Document Security Object)", currentStep++, totalDgs))
            var sodInfo = com.iraq.nireader.data.model.SodSecurityInfo()
            try {
                val sodIn: InputStream = passportService.getInputStream(PassportService.EF_SOD)
                val sodFile = SODFile(sodIn)
                sodInfo = NfcDataGroupParser.parseSod(sodFile)
            } catch (e: Exception) {
                // SOD failed or not present
            }

            val readDuration = System.currentTimeMillis() - startTime
            val nfcData = NfcData(
                authProtocol = authProtocol,
                isAuthSuccessful = true,
                dg1Data = dg1Mrz,
                dg2FacePresent = dg2Present,
                dg11Details = dg11Details,
                dg13Details = if (dg13Map.isNotEmpty()) dg13Map else null,
                sodInfo = sodInfo,
                readDurationMs = readDuration
            )

            emit(NfcReadStatus.Success(nfcData, faceBitmap, faceBase64))

        } catch (e: Exception) {
            emit(
                NfcReadStatus.Error(
                    message = e.localizedMessage ?: "Error during NFC reading",
                    throwable = e
                )
            )
        } finally {
            try {
                passportService?.close()
            } catch (e: Exception) {
                // Ignore close errors
            }
            try {
                if (isoDep.isConnected) {
                    isoDep.close()
                }
            } catch (e: Exception) {
                // Ignore close errors
            }
        }
    }.flowOn(Dispatchers.IO)
}
