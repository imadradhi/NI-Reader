import SwiftUI

// MARK: - Main iOS Application View
public struct MainView: View {
    
    @StateObject private var viewModel = MainViewModelIOS()
    @State private var showBacDialog = false
    @State private var showSettingsDialog = false
    @State private var showDebugLogs = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.08, blue: 0.12).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Card
                headerSection
                
                // Main Dynamic Content Area
                ZStack {
                    switch viewModel.currentStep {
                    case .idle:
                        idleWelcomeView
                    case .cameraFront, .cameraBack:
                        cameraView
                    case .nfcTap:
                        nfcTapView
                    case .verification, .sending, .success:
                        VerificationSummaryView(viewModel: viewModel)
                    }
                    
                    // Diagnostic Logs Overlay
                    if showDebugLogs {
                        debugLogsOverlay
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Status Bar
                bottomStatusBar
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.7))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Iraqi National ID Reader")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Unified Iraqi National ID Companion Reader")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { showSettingsDialog = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                
                Button(action: { showDebugLogs.toggle() }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
            }
            
            // Status Indicators Pill Row
            HStack(spacing: 8) {
                statusPill(title: "USB: Connected", isSuccess: viewModel.isApiConnected)
                statusPill(title: viewModel.isApiConnected ? "API: Connected" : "API: Disconnected", isSuccess: viewModel.isApiConnected)
                statusPill(title: viewModel.isNfcReady ? "NFC: Ready" : "NFC: Disabled", isSuccess: viewModel.isNfcReady)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.10))
    }
    
    private func statusPill(title: String, isSuccess: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isSuccess ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(20)
    }
    
    // MARK: - Step 1: Idle Welcome View
    private var idleWelcomeView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.9))
            
            Text("Iraqi National ID Reader")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("Start the reading workflow by scanning the card followed by NFC chip reading.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                viewModel.startScanningFlow()
            }) {
                Text("Start ID Scan")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(red: 0.1, green: 0.6, blue: 0.9))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Button(action: {
                showBacDialog = true
            }) {
                Text("Manual BAC Keys (Test Mode)")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.clear)
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.2, green: 0.8, blue: 0.7), lineWidth: 1.5)
                    )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Camera View with Auto-Capture Frame
    private var cameraView: some View {
        ZStack {
            CameraPreviewView(session: viewModel.cameraManager.getCaptureSession())
                .ignoresSafeArea()
            
            VStack {
                // Auto Capture Active Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.cameraManager.isCardLocked ? Color.green : Color.yellow)
                        .frame(width: 8, height: 8)
                    Text(viewModel.cameraManager.isCardLocked ? "Auto-Capture: Card Locked ✓" : "Auto-Capture: Active")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.75))
                .cornerRadius(20)
                .padding(.top, 24)
                
                Spacer()
                
                // Guidance Prompt
                Text(viewModel.cameraManager.autoCapturePrompt)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(10)
                    .padding(.bottom, 12)
                
                // Card Bounding Frame Overlay
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        viewModel.cameraManager.isCardLocked ? Color.green : Color.green.opacity(0.8),
                        style: StrokeStyle(lineWidth: viewModel.cameraManager.isCardLocked ? 3.5 : 2, dash: viewModel.cameraManager.isCardLocked ? [] : [8, 4])
                    )
                    .background(viewModel.cameraManager.isCardLocked ? Color.green.opacity(0.15) : Color.green.opacity(0.05))
                    .frame(width: 320, height: 200)
                
                Spacer()
                
                // Manual Capture Button fallback
                Button(action: {
                    viewModel.cameraManager.triggerManualCapture()
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 65, height: 65)
                        .overlay(
                            Circle()
                                .stroke(Color(red: 0.1, green: 0.6, blue: 0.9), lineWidth: 4)
                        )
                }
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Step 3: NFC Tap View
    private var nfcTapView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "wave.3.forward.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.7))
            
            Text("Hold iPhone Near NFC Chip")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Keep the top of your iPhone steady against the back of the card.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.7)))
                .scaleEffect(1.4)
                .padding(.top, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Diagnostic Logs Overlay
    private var debugLogsOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diagnostic Debug Logs")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.7))
                Spacer()
                Button(action: { showDebugLogs = false }) {
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
        .padding(14)
        .frame(height: 220)
        .background(Color(white: 0.08))
        .cornerRadius(16)
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
    
    // MARK: - Bottom Status Bar
    private var bottomStatusBar: some View {
        HStack {
            Text(viewModel.statusMessage)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }
}
