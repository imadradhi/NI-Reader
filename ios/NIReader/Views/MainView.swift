import SwiftUI

// MARK: - Ultra-Premium Full-Screen Main Application View for iOS
public struct MainView: View {
    
    @StateObject private var viewModel = MainViewModelIOS()
    @State private var showBacDialog = false
    @State private var showSettingsDialog = false
    @State private var showDebugLogs = false
    @State private var radarPulsing = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Full Screen Obsidian Mesh Gradient Background
            LinearGradient(
                colors: [Color.darkBgTop, Color.darkBgBottom, Color(red: 0.02, green: 0.03, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Floating Frosted Glass Header
                floatingHeader
                
                // 2. Main Content Dynamic State Machine
                ZStack {
                    switch viewModel.currentStep {
                    case .idle:
                        fullScreenWelcomeView
                    case .cameraFront, .cameraBack:
                        fullScreenCameraView
                    case .nfcTap:
                        fullScreenNfcTapView
                    case .verification, .sending, .success:
                        VerificationSummaryView(viewModel: viewModel)
                    }
                    
                    // Diagnostic Logs Floating Overlay
                    if showDebugLogs {
                        diagnosticLogsOverlay
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 3. Sleek Floating Bottom Status Bar
                floatingStatusBar
            }
        }
        .sheet(isPresented: $showBacDialog) {
            ManualBacSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettingsDialog) {
            ApiSettingsSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.refreshNfcStatus()
        }
    }
    
    // MARK: - Floating Frosted Glass Header
    private var floatingHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Holographic App Emblem Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.neonCyan, .neonEmerald], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Iraqi National ID")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                    Text("ICAO 9303 eMRTD & CoreNFC Reader")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Header Action Buttons
                Button(action: { showSettingsDialog = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                
                Button(action: { withAnimation(.spring()) { showDebugLogs.toggle() } }) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(showDebugLogs ? .neonCyan : .white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            
            // Connection Status Pills Row
            HStack(spacing: 8) {
                statusPill(title: "USB: Connected", isOnline: viewModel.isApiConnected)
                statusPill(title: viewModel.isApiConnected ? "API: 8080" : "API: Offline", isOnline: viewModel.isApiConnected)
                statusPill(title: "NFC: Ready", isOnline: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            Color(red: 0.08, green: 0.10, blue: 0.16)
                .opacity(0.85)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
    
    private func statusPill(title: String, isOnline: Bool) -> some View {
        HStack(spacing: 6) {
            PulsingDotView(isOnline: isOnline)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    // MARK: - Step 1: Full-Screen Welcome View
    private var fullScreenWelcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Glowing Emblem
            ZStack {
                Circle()
                    .fill(Color.neonCyan.opacity(0.12))
                    .frame(width: 160, height: 160)
                Circle()
                    .stroke(LinearGradient(colors: [.neonCyan, .clear, .neonEmerald], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .frame(width: 140, height: 140)
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 6) {
                Text("Unified National ID Reader")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)
                Text("Scan card back to automatically parse MRZ and authenticate electronic smart chip.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            
            VStack(spacing: 14) {
                Button(action: {
                    viewModel.startScanningFlow()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 20, weight: .bold))
                        Text("Start ID Card Scan")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [.neonCyan, Color(red: 0.1, green: 0.5, blue: 0.85)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.neonCyan.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                
                Button(action: {
                    showBacDialog = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.neonGold)
                        Text("Manual BAC Keys (Test Mode)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Full-Screen Camera View with Futuristic HUD
    private var fullScreenCameraView: some View {
        ZStack {
            CameraPreviewView(session: viewModel.cameraManager.getCaptureSession())
                .ignoresSafeArea()
            
            // Dark vignette overlay around target box
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack {
                // Holographic Active Radar Pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.cameraManager.isCardLocked ? Color.neonEmerald : Color.neonGold)
                        .frame(width: 8, height: 8)
                    Text(viewModel.cameraManager.isCardLocked ? "MRZ LOCKED ✓ AUTO-TRANSITION..." : "LIVE MRZ RADAR ACTIVE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(viewModel.cameraManager.isCardLocked ? Color.neonEmerald : Color.white.opacity(0.2), lineWidth: 1.5))
                .padding(.top, 24)
                
                Spacer()
                
                // Holographic Card Bounding HUD
                ZStack {
                    // Frame Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(viewModel.cameraManager.isCardLocked ? Color.neonEmerald.opacity(0.18) : Color.clear)
                    
                    // Thin Frame
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    
                    // Corner Brackets
                    CornerBracketShape(cornerLength: 28, radius: 16)
                        .stroke(viewModel.cameraManager.isCardLocked ? Color.neonEmerald : Color.neonCyan, lineWidth: 3.5)
                    
                    // Prompt in center
                    Text(viewModel.cameraManager.autoCapturePrompt)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                }
                .frame(width: 320, height: 200)
                
                Spacer()
                
                // Floating Frosted Capture Button
                Button(action: {
                    viewModel.cameraManager.triggerManualCapture()
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 4)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 62, height: 62)
                    }
                }
                .padding(.bottom, 28)
            }
        }
    }
    
    // MARK: - Step 3: Interactive Concentric NFC Sonar View
    private var fullScreenNfcTapView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Concentric Expanding Sonar Radar Ripples
            ZStack {
                Circle()
                    .stroke(Color.neonCyan.opacity(0.15), lineWidth: 2)
                    .frame(width: 260, height: 260)
                    .scaleEffect(radarPulsing ? 1.2 : 0.8)
                    .opacity(radarPulsing ? 0.0 : 0.6)
                
                Circle()
                    .stroke(Color.neonCyan.opacity(0.3), lineWidth: 2)
                    .frame(width: 190, height: 190)
                    .scaleEffect(radarPulsing ? 1.15 : 0.9)
                    .opacity(radarPulsing ? 0.2 : 0.8)
                
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.1, green: 0.2, blue: 0.35), Color(red: 0.05, green: 0.1, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 130, height: 130)
                    .overlay(Circle().stroke(Color.neonCyan, lineWidth: 2))
                    .shadow(color: Color.neonCyan.opacity(0.4), radius: 20, x: 0, y: 0)
                
                Image(systemName: "wave.3.forward.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.neonCyan)
            }
            .animation(Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: radarPulsing)
            .onAppear { radarPulsing = true }
            
            VStack(spacing: 8) {
                Text("Hold iPhone Near NFC Chip")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                Text("Keep the top edge of your iPhone steady against the back of the card.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Status Banner
            HStack(spacing: 10) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .neonCyan))
                Text(viewModel.statusMessage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.neonCyan)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.neonCyan.opacity(0.12))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neonCyan.opacity(0.3), lineWidth: 1))
            
            // Direct Complete Action Button (Emergency & Test Fallback)
            Button(action: {
                viewModel.triggerDirectNfcComplete()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.neonEmerald)
                    Text("Direct NFC Complete & Verify")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Floating Diagnostic Logs Drawer
    private var diagnosticLogsOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.neonCyan)
                Text("Live System Diagnostics")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation { showDebugLogs = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.debugLogs, id: \.self) { log in
                        Text(log)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(height: 240)
        .background(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.95))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Floating Bottom Status Bar
    private var floatingStatusBar: some View {
        HStack {
            Text(viewModel.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.9))
    }
}
