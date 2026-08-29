"""
Simulated Client for testing the Desktop API Server (POST /api/national-id/read).
Sends a mock Iraqi National ID read payload with sample data, verification report, and base64 images.
"""

import urllib.request
import json
import base64
import time

SERVER_URL = "http://127.0.0.1:8080/api/national-id/read"

# 1x1 transparent pixel sample base64 for mockup testing
SAMPLE_BASE64_IMAGE = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
)

mock_payload = {
    "deviceId": "Samsung Galaxy S23 (Test Reader)",
    "appVersion": "1.0.0",
    "readTimestamp": int(time.time() * 1000),
    "cardData": {
        "timestamp": int(time.time() * 1000),
        "personalData": {
            "nationalIdNumber": "1995123456",
            "fullNameArabic": "علي حسين كاظم",
            "fullNameEnglish": "ALI HUSSEIN KADHIM",
            "dateOfBirth": "1995-05-15",
            "gender": "M",
            "expiryDate": "2035-05-15",
            "nationality": "IRQ",
            "province": "بغداد",
            "custodyInformation": "متزوج"
        },
        "mrzData": {
            "rawMrzLines": [
                "I<IRQ1995123456<<<<<<<<<<<<<<<",
                "9505156M3505154IRQ<<<<<<<<<<<0",
                "ALI<<HUSSEIN<KADHIM<<<<<<<<<<<"
            ],
            "documentType": "I",
            "issuingCountry": "IRQ",
            "documentNumber": "1995123456",
            "documentNumberCheckDigit": "6",
            "isDocumentNumberValid": True,
            "dateOfBirth": "950515",
            "dateOfBirthCheckDigit": "6",
            "isDateOfBirthValid": True,
            "gender": "M",
            "expiryDate": "350515",
            "expiryDateCheckDigit": "4",
            "isExpiryDateValid": True,
            "nationality": "IRQ",
            "compositeCheckDigit": "0",
            "isCompositeValid": True,
            "primaryIdentifier": "ALI",
            "secondaryIdentifier": "HUSSEIN KADHIM"
        },
        "nfcData": {
            "authProtocol": "BAC",
            "isAuthSuccessful": True,
            "dg1Data": {
                "documentType": "I",
                "issuingCountry": "IRQ",
                "documentNumber": "1995123456",
                "dateOfBirth": "950515",
                "gender": "M",
                "expiryDate": "350515",
                "nationality": "IRQ",
                "primaryIdentifier": "ALI",
                "secondaryIdentifier": "HUSSEIN KADHIM"
            },
            "dg2FacePresent": True,
            "dg11Details": {
                "fullNameNationalLanguage": "علي حسين كاظم",
                "placeOfBirth": "بغداد",
                "custodyInformation": "متزوج"
            },
            "sodInfo": {
                "digestAlgorithm": "SHA-256",
                "signatureAlgorithm": "SHA256withRSA",
                "isSignatureValid": True
            },
            "readDurationMs": 1420
        },
        "images": {
            "frontImageBase64": SAMPLE_BASE64_IMAGE,
            "backImageBase64": SAMPLE_BASE64_IMAGE,
            "chipPhotoBase64": SAMPLE_BASE64_IMAGE
        },
        "verification": {
            "ocrStatus": "PASS",
            "nfcStatus": "PASS",
            "matchingStatus": "PASS",
            "overallStatus": "PASS",
            "fieldChecks": [
                {
                    "fieldName": "Document Number",
                    "ocrValue": "1995123456",
                    "nfcValue": "1995123456",
                    "isMatch": True,
                    "similarityScore": 1.0
                },
                {
                    "fieldName": "Date of Birth",
                    "ocrValue": "950515",
                    "nfcValue": "950515",
                    "isMatch": True,
                    "similarityScore": 1.0
                },
                {
                    "fieldName": "Expiry Date",
                    "ocrValue": "350515",
                    "nfcValue": "350515",
                    "isMatch": True,
                    "similarityScore": 1.0
                },
                {
                    "fieldName": "Name",
                    "ocrValue": "ALI HUSSEIN KADHIM",
                    "nfcValue": "ALI HUSSEIN KADHIM",
                    "isMatch": True,
                    "similarityScore": 1.0
                }
            ],
            "failureReasons": []
        }
    }
}

import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def send_mock_card():
    data_bytes = json.dumps(mock_payload).encode('utf-8')
    req = urllib.request.Request(
        SERVER_URL,
        data=data_bytes,
        headers={'Content-Type': 'application/json'}
    )

    print(f"[+] Sending simulated Iraqi ID read request to {SERVER_URL}...")
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode('utf-8')
            print(f"[OK] Response ({response.status}): {res_body}")
    except Exception as e:
        print(f"[ERROR] Failed to connect to server: {e}")

if __name__ == '__main__':
    send_mock_card()

