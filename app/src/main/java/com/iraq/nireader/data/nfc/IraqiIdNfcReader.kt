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
        private const val ISO_DEP_TIMEOUT_MS = 15000
    }

    /**
     * Reads the Iraqi National ID card from an IsoDep NFC Tag.
     * Emits continuous progress states across 3 stages via Kotlin Flow.
     */
    fun readCard(tag: Tag, authKey: NfcAuthKey): Flow<NfcReadStatus> = flow {
        val startTime = System.currentTimeMillis()
        val isoDep = IsoDep.get(tag)

        if (isoDep == null) {
            emit(NfcReadStatus.Error("الشريحة لا تدعم بروتوكول ISO/IEC 14443-4 (IsoDep)"))
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
            val cardSummary = "$isoType | UID: $uidHex${if (historicalHex != null) " | ATS: $historicalHex" else ""}"
            
            // Stage 1: Chip Detected
            emit(NfcReadStatus.CardDiscovered(
                historicalBytes = cardSummary,
                protocol = isoType,
                message = "المرحلة الأولى: تم الكشف عن شريحة NFC بنجاح ✓"
            ))

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
            var isAuthSucceeded = false
            val bacKey = authKey.toBacKeySpec()

            // Stage 2: Communicating & Authenticating (BAC / PACE)
            try {
                emit(NfcReadStatus.Authenticating(
                    protocol = "BAC",
                    message = "المرحلة الثانية: يتم التواصل وتأكيد المصادقة الأمنية (BAC)..."
                ))
                passportService.sendSelectApplet(false)
                passportService.doBAC(bacKey)
                authProtocol = "BAC"
                isAuthSucceeded = true
            } catch (bacException: Exception) {
                // If BAC fails or card requires PACE, attempt PACE fallback
                try {
                    val cardAccessFile = CardAccessFile(passportService.getInputStream(PassportService.EF_CARD_ACCESS))
                    val securityInfos = cardAccessFile.securityInfos
                    if (securityInfos != null && securityInfos.isNotEmpty()) {
                        for (secInfo in securityInfos) {
                            if (secInfo is PACEInfo) {
                                emit(NfcReadStatus.Authenticating(
                                    protocol = "PACE (${secInfo.protocolOIDString})",
                                    message = "المرحلة الثانية: يتم التواصل وتأكيد المصادقة الأمنية (PACE)..."
                                ))
                                passportService.doPACE(
                                    bacKey,
                                    secInfo.objectIdentifier,
                                    PACEInfo.toParameterSpec(secInfo.parameterId),
                                    null
                                )
                                authProtocol = "PACE"
                                isAuthSucceeded = true
                                break
                            }
                        }
                    }
                } catch (paceException: Exception) {
                    // PACE also failed
                }

                if (!isAuthSucceeded) {
                    val msg = bacException.message.orEmpty()
                    val isAuthFail = msg.contains("6982") || msg.contains("6300") || msg.contains("BAC") || msg.contains("Security")
                    emit(
                        NfcReadStatus.Error(
                            message = if (isAuthFail) {
                                "فشلت المصادقة الأمنية (BAC)! الأرقام المدخلة غير مطابقة لمفتاح تشفير الشريحة. تحقق من رقم الوثيقة وتاريخ الميلاد."
                            } else {
                                "خطأ مصادقة الشريحة: ${bacException.localizedMessage ?: bacException.javaClass.simpleName}"
                            },
                            isAuthFailure = isAuthFail,
                            failurePhase = "BAC_AUTH",
                            throwable = bacException
                        )
                    )
                    return@flow
                }
            }

            // Stage 3: Reading Data Groups (DG1, DG2, DG11, DG13, SOD)
            val totalDgs = 4

            // DG1 - MRZ Info (25%)
            emit(NfcReadStatus.ReadingDataGroup("DG1 (البيانات النصية)", 1, totalDgs, 25, "المرحلة الثالثة: جاري قراءة بيانات الهوية ورقم الوثيقة (DG1)..."))
            val dg1In: InputStream = passportService.getInputStream(PassportService.EF_DG1)
            val dg1File = DG1File(dg1In)
            val dg1Mrz = NfcDataGroupParser.parseDg1(dg1File)

            // DG2 - Facial Biometric Image (60%)
            emit(NfcReadStatus.ReadingDataGroup("DG2 (الصورة الحيوية للوجه)", 2, totalDgs, 60, "قراءة الصورة الشخصية من الشريحة..."))
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

            // DG11 - Personal details (80%)
            emit(NfcReadStatus.ReadingDataGroup("DG11 (التفاصيل الإضافية)", 3, totalDgs, 80, "قراءة الاسم العربي والتفاصيل الشخصية..."))
            var dg11Details = com.iraq.nireader.data.model.Dg11PersonalDetails()
            try {
                val dg11In: InputStream = passportService.getInputStream(PassportService.EF_DG11)
                val dg11File = DG11File(dg11In)
                dg11Details = NfcDataGroupParser.parseDg11(dg11File)
            } catch (e: Exception) {
                // DG11 not present
            }

            // DG13 - Optional National Security Fields
            val dg13Map = mutableMapOf<String, String>()
            try {
                val dg13In: InputStream = passportService.getInputStream(PassportService.EF_DG13)
                dg13Map["status"] = "Present"
            } catch (e: Exception) {
                // DG13 optional
            }

            // SOD - Security Object File (100%)
            emit(NfcReadStatus.ReadingDataGroup("SOD (التواقيع والأمان الرقمي)", 4, totalDgs, 95, "التحقق من التوقيع الرقمي للوثيقة..."))
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
            val isTagLost = e is java.io.IOException || e is android.nfc.TagLostException || e.message?.contains("Tag was lost") == true
            emit(
                NfcReadStatus.Error(
                    message = if (isTagLost) {
                        "انقطع الاتصال بالشريحة! يرجى تثبيت البطاقة خلف الهاتف وإعادة المحاولة."
                    } else {
                        "خطأ في قراءة NFC: ${e.localizedMessage ?: e.javaClass.simpleName}"
                    },
                    isCardLost = isTagLost,
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
