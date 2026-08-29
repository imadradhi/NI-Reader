import Foundation
import UIKit

// MARK: - ByteUtils
public final class ByteUtils {
    public static func toHexString(_ data: Data) -> String {
        return data.map { String(format: "%02hhX", $0) }.joined()
    }
    
    public static func fromHexString(_ hex: String) -> Data? {
        var cleanHex = hex.replacingOccurrences(of: " ", with: "")
        var data = Data()
        while !cleanHex.isEmpty {
            let subHex = String(cleanHex.prefix(2))
            cleanHex = String(cleanHex.dropFirst(2))
            guard let byte = UInt8(subHex, radix: 16) else { return nil }
            data.append(byte)
        }
        return data
    }
}

// MARK: - ImageUtils
public final class ImageUtils {
    public static func imageToBase64(_ image: UIImage, compressionQuality: CGFloat = 0.85) -> String? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        return data.base64EncodedString()
    }
    
    public static func base64ToImage(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - SecurityZeroizer
public final class SecurityZeroizer {
    public static func wipeData(_ data: inout Data?) {
        guard var d = data else { return }
        d.resetBytes(in: 0..<d.count)
        data = nil
    }
    
    public static func wipeImage(_ image: inout UIImage?) {
        image = nil
    }
    
    public static func requestMemoryPurge() {
        // Clear URLCache and encourage ARC cleanup
        URLCache.shared.removeAllCachedResponses()
    }
}
