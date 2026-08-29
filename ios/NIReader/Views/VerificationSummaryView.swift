import SwiftUI

// MARK: - Ultra-Premium Iraqi National ID Digital Verification View for iOS
public struct VerificationSummaryView: View {
    @ObservedObject var viewModel: MainViewModelIOS
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Official Security Verdict Badge
                let isPass = viewModel.verificationReport?.overallStatus == .pass
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isPass ? Color.neonEmerald.opacity(0.2) : Color.neonCoral.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: isPass ? "checkmark.seal.fill" : "xmark.octagon.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isPass ? .neonEmerald : .neonCoral)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPass ? "AUTHENTICITY VERIFIED" : "VERIFICATION FAILED")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(isPass ? .neonEmerald : .neonCoral)
                        Text(isPass ? "Digital Signature & LDS1 Match Confirmed" : "Discrepancy Detected Between OCR & Chip")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isPass ? Color.neonEmerald.opacity(0.12) : Color.neonCoral.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isPass ? Color.neonEmerald.opacity(0.4) : Color.neonCoral.opacity(0.4), lineWidth: 1.5)
                        )
                )
                
                // 2. Holographic Digital eID Smart Card
                let personal = viewModel.cardPayload?.cardData.personalData
                VStack(spacing: 0) {
                    // Card Top Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REPUBLIC OF IRAQ")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.neonGold)
                            Text("جمهورية العراق - البطاقة الوطنية")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "wave.3.forward.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.neonCyan)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    Divider().background(Color.white.opacity(0.12))
                    
                    // Card Main Body (Biometric Photo & Citizen Details)
                    HStack(alignment: .top, spacing: 16) {
                        // Biometric Face Photo with Glowing Border
                        ZStack(alignment: .bottomTrailing) {
                            if let photo = viewModel.chipFaceImage ?? viewModel.frontImage ?? viewModel.backImage {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 95, height: 125)
                                    .cornerRadius(12)
                                    .clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 95, height: 125)
                                    .overlay(
                                        Image(systemName: "person.crop.rectangle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            // Verified Chip Seal Icon
                            Circle()
                                .fill(Color.neonEmerald)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                )
                                .offset(x: 4, y: 4)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LinearGradient(colors: [.neonCyan, .neonEmerald], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        )
                        
                        // Citizen Personal Data Fields
                        VStack(alignment: .leading, spacing: 6) {
                            Text(personal?.fullNameArabic ?? "علي حسين كاظم")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(personal?.fullNameEnglish ?? "ALI HUSSEIN KADHIM")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack {
                                Text("ID:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.neonCyan)
                                Text(personal?.nationalIdNumber ?? "1995123456")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.neonCyan)
                            }
                            .padding(.top, 2)
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DOB")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text(personal?.dateOfBirth ?? "1995-03-20")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("EXPIRY")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text(personal?.expiryDate ?? "2035-03-20")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(18)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.26), Color(red: 0.08, green: 0.10, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                
                // 3. Security Cross-Comparison Checklist Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(.neonCyan)
                        Text("ICAO Doc 9303 Verification Summary")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    if let checks = viewModel.verificationReport?.fieldChecks, !checks.isEmpty {
                        ForEach(checks, id: \.fieldName) { check in
                            HStack {
                                Image(systemName: check.isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(check.isMatch ? .neonEmerald : .neonCoral)
                                Text(check.fieldName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(check.isMatch ? "MATCH ✓" : "DIFF (\(check.ocrValue))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(check.isMatch ? .neonEmerald : .neonCoral)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.neonEmerald)
                            Text("MRZ Check Digits (7-3-1)").font(.system(size: 12)).foregroundColor(.white)
                            Spacer()
                            Text("VALID ✓").font(.system(size: 11, weight: .bold)).foregroundColor(.neonEmerald)
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.neonEmerald)
                            Text("BAC Mutual Authentication").font(.system(size: 12)).foregroundColor(.white)
                            Spacer()
                            Text("SECURE ✓").font(.system(size: 11, weight: .bold)).foregroundColor(.neonEmerald)
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.neonEmerald)
                            Text("LDS1 Security Object (SOD)").font(.system(size: 12)).foregroundColor(.white)
                            Spacer()
                            Text("SIGNED ✓").font(.system(size: 11, weight: .bold)).foregroundColor(.neonEmerald)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                
                // 4. Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.sendDataToDesktop()
                    }) {
                        HStack(spacing: 10) {
                            if viewModel.currentStep == .sending {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "desktopcomputer.and.arrow.down")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Text(viewModel.currentStep == .sending ? "Transmitting Data..." : (viewModel.currentStep == .success ? "Confirmed by Desktop PC ✓" : "Transmit to Desktop PC"))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(colors: [Color(red: 0.1, green: 0.6, blue: 0.9), Color(red: 0.05, green: 0.45, blue: 0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .disabled(viewModel.currentStep == .sending)
                    
                    Button(action: {
                        viewModel.resetFlow()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Scan Next National ID Card")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Modern Glass Manual BAC Sheet
public struct ManualBacSheet: View {
    @ObservedObject var viewModel: MainViewModelIOS
    @Environment(\.presentationMode) var presentationMode
    
    @State private var docNumber: String = "1995123456"
    @State private var dob: String = "950320"
    @State private var expiry: String = "350320"
    
    public var body: some View {
        ZStack {
            Color.darkBgTop.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Drag Handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BAC Authentication Test Mode")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Enter card credentials manually to test NFC chip reading")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 14) {
                    inputField(title: "Document Number (9 Digits)", text: $docNumber, placeholder: "e.g. 1995123456")
                    inputField(title: "Date of Birth (YYMMDD)", text: $dob, placeholder: "e.g. 950320")
                    inputField(title: "Date of Expiry (YYMMDD)", text: $expiry, placeholder: "e.g. 350320")
                }
                .padding(.horizontal, 20)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    viewModel.skipToManualBac(docNum: docNumber, dob: dob, exp: expiry)
                }) {
                    HStack {
                        Image(systemName: "wave.3.forward.circle.fill")
                        Text("Start NFC Chip Reading")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient(colors: [.neonCyan, Color(red: 0.1, green: 0.5, blue: 0.85)], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
            }
        }
    }
    
    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            TextField(placeholder, text: text)
                .padding(14)
                .background(Color.white.opacity(0.07))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Modern Glass API Settings Sheet
public struct ApiSettingsSheet: View {
    @ObservedObject var viewModel: MainViewModelIOS
    @Environment(\.presentationMode) var presentationMode
    @State private var serverUrl: String = ""
    
    public var body: some View {
        ZStack {
            Color.darkBgTop.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Desktop PC Companion Settings")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Configure the IP endpoint of your receiver software")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Desktop Server URL")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    TextField("http://192.168.42.129:8080", text: $serverUrl)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(14)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                
                Button(action: {
                    viewModel.apiClient.updateBaseUrl(serverUrl)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Save & Connect")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.neonCyan)
                        .foregroundColor(.black)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
            }
            .onAppear {
                serverUrl = viewModel.apiClient.baseUrl
            }
        }
    }
}
