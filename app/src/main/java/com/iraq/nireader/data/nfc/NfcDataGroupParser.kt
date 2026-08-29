package com.iraq.nireader.data.nfc

import android.graphics.Bitmap
import com.iraq.nireader.data.model.*
import com.iraq.nireader.utils.ImageUtils
import org.jmrtd.lds.icao.*
import org.jmrtd.lds.iso19794.FaceImageInfo
import org.jmrtd.lds.iso19794.FaceInfo
import org.jmrtd.lds.SODFile

/**
 * Extracts and maps JMRTD / ICAO 9303 Data Groups into domain models.
 */
object NfcDataGroupParser {

    /**
     * Parses DG1 into Dg1MrzInfo
     */
    fun parseDg1(dg1File: DG1File): Dg1MrzInfo {
        val mrzInfo = dg1File.mrzInfo
        return Dg1MrzInfo(
            documentType = mrzInfo.documentType.toString(),
            issuingCountry = mrzInfo.issuingState ?: "IRQ",
            documentNumber = mrzInfo.documentNumber?.replace("<", "")?.trim() ?: "",
            dateOfBirth = mrzInfo.dateOfBirth ?: "",
            gender = mrzInfo.gender?.toString() ?: "",
            expiryDate = mrzInfo.dateOfExpiry ?: "",
            nationality = mrzInfo.nationality ?: "IRQ",
            primaryIdentifier = mrzInfo.primaryIdentifier?.replace("<", " ")?.trim() ?: "",
            secondaryIdentifier = mrzInfo.secondaryIdentifier?.replace("<", " ")?.trim() ?: ""
        )
    }

    /**
     * Extracts biometric face photo from DG2
     */
    fun parseDg2FaceImage(dg2File: DG2File): Pair<Bitmap?, String?> {
        return try {
            val faceInfos: List<FaceInfo> = dg2File.faceInfos
            for (faceInfo in faceInfos) {
                val faceImageInfos: List<FaceImageInfo> = faceInfo.faceImageInfos
                for (faceImageInfo in faceImageInfos) {
                    val imageLength = faceImageInfo.imageLength
                    val inputStream = faceImageInfo.imageInputStream
                    val bitmap = ImageUtils.decodeFaceImageStream(inputStream, imageLength)
                    if (bitmap != null) {
                        val base64 = ImageUtils.bitmapToBase64(bitmap)
                        return Pair(bitmap, base64)
                    }
                }
            }
            Pair(null, null)
        } catch (e: Exception) {
            e.printStackTrace()
            Pair(null, null)
        }
    }

    /**
     * Parses DG11 (Additional Personal Details) if present
     */
    fun parseDg11(dg11File: DG11File): Dg11PersonalDetails {
        return try {
            Dg11PersonalDetails(
                fullNameNationalLanguage = dg11File.nameOfHolder,
                placeOfBirth = dg11File.placeOfBirth?.joinToString(", "),
                telephone = dg11File.telephone,
                profession = dg11File.profession,
                title = dg11File.title,
                personalSummary = dg11File.personalSummary,
                custodyInformation = dg11File.custodyInformation
            )
        } catch (e: Exception) {
            Dg11PersonalDetails()
        }
    }

    /**
     * Parses SOD (Security Object Document)
     */
    fun parseSod(sodFile: SODFile): SodSecurityInfo {
        return try {
            val digestAlgorithm = sodFile.digestAlgorithm
            val docSigningCert = sodFile.docSigningCertificate
            val issuerName = docSigningCert?.issuerX500Principal?.name
            val serialNumber = docSigningCert?.serialNumber?.toString(16)
            val sigAlg = docSigningCert?.sigAlgName

            SodSecurityInfo(
                digestAlgorithm = digestAlgorithm,
                signatureAlgorithm = sigAlg,
                issuerName = issuerName,
                serialNumber = serialNumber,
                isSignatureValid = true
            )
        } catch (e: Exception) {
            SodSecurityInfo(isSignatureValid = false)
        }
    }
}
