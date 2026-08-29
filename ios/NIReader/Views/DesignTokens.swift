import SwiftUI

// MARK: - Color & Visual Design System Tokens for iOS
public extension Color {
    static let darkBgTop = Color(red: 0.04, green: 0.06, blue: 0.10)
    static let darkBgBottom = Color(red: 0.07, green: 0.09, blue: 0.15)
    static let glassCard = Color(red: 0.10, green: 0.13, blue: 0.20).opacity(0.75)
    static let glassStroke = Color.white.opacity(0.12)
    static let neonCyan = Color(red: 0.02, green: 0.71, blue: 0.83)
    static let neonEmerald = Color(red: 0.06, green: 0.78, blue: 0.51)
    static let neonGold = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let neonCoral = Color(red: 0.96, green: 0.32, blue: 0.32)
}

// MARK: - Corner Bracket Shape for Futuristic HUD
public struct CornerBracketShape: Shape {
    public let cornerLength: CGFloat
    public let radius: CGFloat
    
    public init(cornerLength: CGFloat = 24, radius: CGFloat = 12) {
        self.cornerLength = cornerLength
        self.radius = radius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Top-Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))
        
        // Top-Right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))
        
        // Bottom-Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
        
        // Bottom-Left
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
        
        return path
    }
}

// MARK: - Pulsing Neon Indicator Dot
public struct PulsingDotView: View {
    public let isOnline: Bool
    @State private var isPulsing = false
    
    public init(isOnline: Bool) {
        self.isOnline = isOnline
    }
    
    public var body: some View {
        ZStack {
            if isOnline {
                Circle()
                    .fill(Color.neonEmerald.opacity(0.35))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.8)
                    .animation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)
                    .onAppear { isPulsing = true }
            }
            Circle()
                .fill(isOnline ? Color.neonEmerald : Color.neonCoral)
                .frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
    }
}
