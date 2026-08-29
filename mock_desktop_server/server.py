"""
Mock Desktop Receiver Server for Iraqi National ID Reader.
Runs on PC at http://0.0.0.0:8080 (or localhost / USB network adapter IP).
Receives and displays card data, verification results, and saves/displays images.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import base64
import os
import time
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')


PORT = 8080
OUTPUT_DIR = "received_cards"
os.makedirs(OUTPUT_DIR, exist_ok=True)

class NationalIdReceiverHandler(BaseHTTPRequestHandler):

    def _set_headers(self, status_code=200):
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_GET(self):
        if self.path == "/api/health":
            self._set_headers(200)
            self.wfile.write(json.dumps({
                "status": "UP",
                "service": "Iraqi National ID Desktop Host",
                "timestamp": int(time.time() * 1000)
            }).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Endpoint not found"}).encode('utf-8'))

    def do_POST(self):
        if self.path == "/api/national-id/read":
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            try:
                data = json.loads(body.decode('utf-8'))
                card_data = data.get('cardData', {})
                personal = card_data.get('personalData', {})
                verification = card_data.get('verification', {})
                images = card_data.get('images', {})

                timestamp = int(time.time())
                doc_num = personal.get('nationalIdNumber', 'UNKNOWN')
                session_folder = os.path.join(OUTPUT_DIR, f"{doc_num}_{timestamp}")
                os.makedirs(session_folder, exist_ok=True)

                # Save JSON data
                with open(os.path.join(session_folder, "card_payload.json"), "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)

                # Save Biometric Face Image if present
                chip_photo_b64 = images.get('chipPhotoBase64')
                if chip_photo_b64:
                    with open(os.path.join(session_folder, "chip_biometric_face.jpg"), "wb") as f:
                        f.write(base64.b64decode(chip_photo_b64))

                # Save Front / Back Card Photos if present
                if images.get('frontImageBase64'):
                    with open(os.path.join(session_folder, "front_card.jpg"), "wb") as f:
                        f.write(base64.b64decode(images['frontImageBase64']))
                if images.get('backImageBase64'):
                    with open(os.path.join(session_folder, "back_card.jpg"), "wb") as f:
                        f.write(base64.b64decode(images['backImageBase64']))

                print("\n" + "=" * 60)
                print(f"📥 [RECEIVED IRAQI NATIONAL ID READ EVENT]")
                print(f"• Document Number : {personal.get('nationalIdNumber')}")
                print(f"• Full Name (AR)  : {personal.get('fullNameArabic')}")
                print(f"• Full Name (EN)  : {personal.get('fullNameEnglish')}")
                print(f"• Date of Birth   : {personal.get('dateOfBirth')} ({personal.get('gender')})")
                print(f"• Expiry Date     : {personal.get('expiryDate')}")
                print(f"• Verification    : {verification.get('overallStatus')}")
                print(f"• Saved To Folder : {session_folder}")
                print("=" * 60 + "\n")

                self._set_headers(200)
                response_payload = {
                    "status": "SUCCESS",
                    "message": "Card data received and processed successfully",
                    "transactionId": f"TXN-{timestamp}-{doc_num}"
                }
                self.wfile.write(json.dumps(response_payload).encode('utf-8'))

            except Exception as e:
                print(f"❌ Error processing card payload: {e}")
                self._set_headers(400)
                self.wfile.write(json.dumps({
                    "status": "INVALID_DATA",
                    "message": str(e)
                }).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"status": "FAILED", "message": "Endpoint not found"}).encode('utf-8'))

def run():
    server_address = ('', PORT)
    httpd = HTTPServer(server_address, NationalIdReceiverHandler)
    print(f"🚀 Iraqi National ID Desktop API Server listening on port {PORT}...")
    print(f"• Health Endpoint : http://localhost:{PORT}/api/health")
    print(f"• Read Endpoint   : http://localhost:{PORT}/api/national-id/read\n")
    httpd.serve_forever()

if __name__ == '__main__':
    run()
