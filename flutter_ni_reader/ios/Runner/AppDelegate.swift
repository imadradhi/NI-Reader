import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var nfcBridge: IraqiNfcNativeBridge?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let nfcChannel = FlutterMethodChannel(name: "com.iraq.nireader/nfc", binaryMessenger: controller.binaryMessenger)
        
        nfcBridge = IraqiNfcNativeBridge()
        
        nfcChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            
            if call.method == "startNfcRead" {
                if let args = call.arguments as? [String: Any] {
                    let docNumber = args["documentNumber"] as? String ?? ""
                    let dob = args["dateOfBirth"] as? String ?? ""
                    let expiry = args["expiryDate"] as? String ?? ""
                    self.nfcBridge?.startNfcRead(docNumber: docNumber, dob: dob, expiry: expiry, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing NFC authentication parameters", details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
