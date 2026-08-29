import SwiftUI

// MARK: - Verification Summary View for iOS
public struct VerificationSummaryView: View {
    @ObservedObject var viewModel: MainViewModelIOS
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Verdict Banner
                let isPass = viewModel.verificationReport?.overallStatus == .pass
                HStack(spacing: 8) {
                    Image(systemName: isPass ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isPass ? .green : .red)
                    Text(isPass ? "Verification Result: PASS ✓" : "Verification: Mismatch Detected ✕")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isPass ? Color.green.opacity(0.25) : Color.red.opacity(0.25))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isPass ? Color.green : Color.red, lineWidth: 1.5)
                )
                
                // 2. Biometric Face & Personal Details Card
                let personal = viewModel.cardPayload?.cardData.personalData
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        if let photo = viewModel.chipFaceImage ?? viewModel.frontImage {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 115)
                                .cornerRadius(8)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(white: 0.15))
                                .frame(width: 90, height: 115)
                                .overlay(
                                    Image(systemName: "person.crop.rectangle")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(personal?.fullNameArabic ?? "الاسم غير متوفر في DG11")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(personal?.fullNameEnglish ?? "FULL NAME")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("Document No: \(personal?.nationalIdNumber ?? "000000000")")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.7))
                            
                            Text("DOB: \(personal?.dateOfBirth ?? "") (\(personal?.gender ?? ""))")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                }
                .padding(14)
                .background(Color(white: 0.12))
                .cornerRadius(12)
                
                // 3. Comparison Checklist Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("OCR vs NFC Chip Cross-Comparison")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.7))
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    if let checks = viewModel.verificationReport?.fieldChecks {
                        ForEach(checks, id: \.fieldName) { check in
                            HStack {
                                Image(systemName: check.isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(check.isMatch ? .green : .red)
                                Text(check.fieldName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(check.isMatch ? "Match ✓" : "Diff (\(check.ocrValue) vs \(check.nfcValue))")
                                    .font(.system(size: 12))
                                    .foregroundColor(check.isMatch ? .green : .red)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color(white: 0.12))
                .cornerRadius(12)
                
                // 4. Action Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.sendDataToDesktop()
                    }) {
                        HStack {
                            if viewModel.currentStep == .sending {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(viewModel.currentStep == .sending ? "Sending..." : (viewModel.currentStep == .success ? "Sent Successfully ✓" : "Send to Desktop PC"))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 0.1, green: 0.6, blue: 0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.currentStep == .sending)
                    
                    Button(action: {
                        viewModel.resetFlow()
                    }) {
                        Text("Scan New Card")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
    }
}

// MARK: - Manual BAC Sheet
public struct ManualBacSheet: View {
    @ObservedObject var viewModel: MainViewModelIOS
    @Environment(\.presentationMode) var presentationMode
    
    @State private var docNumber: String = "1995123456"
    @State private var dob: String = "950320"
    @State private var expiry: String = "350320"
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Manual BAC Keys (Test Mode)")) {
                    TextField("Document Number (9 Digits)", text: $docNumber)
                        .autocapitalization(.allCharacters)
                    TextField("Date of Birth (YYMMDD e.g. 950320)", text: $dob)
                        .keyboardType(.numberPad)
                    TextField("Date of Expiry (YYMMDD e.g. 350320)", text: $expiry)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        viewModel.skipToManualBac(docNum: docNumber, dob: dob, exp: expiry)
                    }) {
                        HStack {
                            Spacer()
                            Text("Start NFC Reading")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
            }
            .navigationBarTitle("BAC Test Mode", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - API Settings Sheet
public struct ApiSettingsSheet: View {
    @ObservedObject var viewModel: MainViewModelIOS
    @Environment(\.presentationMode) var presentationMode
    @State private var serverUrl: String = ""
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Desktop Server Connection (USB / WiFi)")) {
                    TextField("Desktop Server URL", text: $serverUrl)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button(action: {
                        viewModel.apiClient.updateBaseUrl(serverUrl)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("Save & Test Connection")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
            }
            .navigationBarTitle("API Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                serverUrl = viewModel.apiClient.baseUrl
            }
        }
    }
}
