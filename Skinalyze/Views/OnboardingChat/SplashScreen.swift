import SwiftUI
import AVKit

struct SplashScreen: View {
    
    @EnvironmentObject var router: Router
    @State private var isChecked: Bool = false
    @State private var showPrivacyPolicy: Bool = false
    
    var body: some View {
            ZStack {
                VStack {
                    Image("ProfileAtas")
                        .resizable()
                        .frame(width: .infinity, height: 250)
                    Spacer()
                }
                VStack {
                    
                    Spacer()
                    
                    ResizableGIFPlayer(gifName: "Hover")
                    .padding(.bottom, 20)
                    .padding(.top, 100)
                    
                    
                    Text("Welcome to Skinalyze")
                        .fontWeight(.semibold)
                        .font(.title)
                    Text("Face scan for analysis results\naccording to acne needs.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    HStack {
                        Button(action: {
                            isChecked.toggle() // Toggle the checkbox state
                        }) {
                            Image(systemName: isChecked ? "checkmark.square" : "square") // Checkbox image
                                .foregroundColor(.blue) // Optional: Color for the checkbox
                                .font(.title2) // Adjust size if needed
                        }
                        
                        Text("I agree to the")
                        Text("Terms and Conditions")
                            .underline()
                            .foregroundColor(.blue)
                            .onTapGesture {
                                showPrivacyPolicy = true
                            } 
                    }
                    .padding()
                        PrimaryBTN(text: "Let’s Start", isDisabled: !isChecked, action: {
                            router.navigate(to: .chatView(isFromStartup: true))
                        })
                    
                }
                .padding(.bottom, 40)
            }
            .background(Color("splashScreen"))
            .ignoresSafeArea()
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
    }
}

#Preview {
    SplashScreen()
}

struct PrivacyPolicyView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy for Skinalyze")
                        .font(.title)
                        .bold()
                        .padding(.bottom, 8)
                    
                    Group {
                        Text("""
                        At Skinalyze, your privacy is our top priority. This Privacy Policy explains how your data is handled when you use our application. By using Skinalyze, you agree to the practices outlined below.
                        """)
                        
                        SectionTitle("1. No Data Collection by Skinalyze")
                        Text("""
                        Skinalyze does not collect, store, or access any of your personal data or photos. All processing is performed locally on your device using Apple’s advanced machine learning frameworks, such as CreateML.
                        """)
                        
                        SectionTitle("2. Data Handling and Storage")
                        Text("""
                        - All image processing and AI analysis of your facial photos are conducted locally on your device. Your data never leaves your device during these processes.
                        - Any saved information, such as skincare logs or progress tracking data, is stored securely in your personal iCloud account via CloudKit.
                        - Skinalyze does not have access to your iCloud account or its contents. Your data is fully controlled and managed by you through your Apple ID account.
                        """)
                        
                        SectionTitle("3. Facial Data Specifics")
                        Text("""
                        - Skinalyze uses facial photos that you upload locally for skin analysis purposes only. These photos are processed entirely on your device and are not shared, uploaded, or stored externally.
                        - Facial data is used solely to analyze your skin condition and provide tailored skincare recommendations.
                        - Facial data is not shared with any third parties. Any photos or logs you save are retained solely in your personal iCloud account, where you can manage or delete them at any time.
                        """)
                    }
                    
                    Group {
                        SectionTitle("4. Data Sharing")
                        Text("""
                        - Skinalyze does not collect or share any personal data or facial photos with third parties.
                        - The app operates fully within the Apple ecosystem, ensuring secure handling of your data through iCloud and local processing.
                        """)
                        
                        SectionTitle("5. Data Security")
                        Text("""
                        - All photo analysis is conducted locally on your device, ensuring your data remains private.
                        - Saved data is securely stored in your personal iCloud account, managed by Apple's robust security protocols.
                        - Access to your data is protected by your Apple ID credentials.
                        """)
                        
                        SectionTitle("6. Your Rights")
                        Text("""
                        As a Skinalyze user, you have the following rights:
                        
                        - **Full Control**: You control all saved data via your iCloud account.
                        - **Delete Data**: Delete any saved photos or skincare logs directly from your device or iCloud account.
                        - **Withdraw Access**: You can stop using the app and revoke its access to your iCloud account at any time.
                        """)
                    }
                    
                    Group {
                        SectionTitle("7. Cookies and Tracking")
                        Text("Skinalyze does not use cookies or external tracking technologies.")
                        
                        SectionTitle("8. Changes to This Privacy Policy")
                        Text("We may update this Privacy Policy from time to time. Any changes will be communicated through app updates or notifications.")
                        
                        SectionTitle("9. Contact Us")
                        Text("If you have any questions or concerns about this Privacy Policy, please contact us at:")
                        Text("Email: skinalyze.id@gmail.com")
                            .foregroundColor(.blue)
                    }
                    
                    Text("By using Skinalyze, you agree to this Privacy Policy and consent to the practices outlined above.")
                        .padding(.top, 16)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Helper function for section titles
    private func SectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .bold()
            .padding(.top, 8)
    }
}


//struct PrivacyPolicyView: View {
//    var body: some View {
//        NavigationView {
//            ScrollView {
//                VStack(alignment: .leading, spacing: 16) {
//                    Text("Privacy Policy for Skinalyze")
//                        .font(.title)
//                        .bold()
//                        .padding(.bottom, 8)
//                    
////                    Text("Effective Date: [Insert Date]")
////                        .italic()
////                        .padding(.bottom, 16)
//                    
//                    Group {
//                        Text("At Skinalyze, your privacy is our top priority. This Privacy Policy explains how we collect, use, and protect your data when you use our application. By using Skinalyze, you agree to the practices outlined in this document.")
//                        
//                        SectionTitle("1. Data We Collect")
//                        Text("""
//                        When you use Skinalyze, we may collect the following types of data:
//                        
//                        - Facial Photos: Uploaded for skin analysis purposes.
//                        - Skincare Product Information: Saved products and logs to track your progress.
//                        - Usage Data: Includes app activity, feature interactions, and analytics to improve the app experience.
//                        """)
//                        
//                        SectionTitle("2. How We Use Your Data")
//                        Text("""
//                        Your data is used for the following purposes:
//                        
//                        - To analyze your facial skin and provide ingredient recommendations.
//                        - To save and organize your skincare product details.
//                        - To track and display your skin progress over time.
//                        - To improve our app through aggregated, anonymized analytics (does not include personal data).
//                        """)
//                        
//                        SectionTitle("3. Where Your Data is Stored")
//                        Text("""
//                        - CloudKit Storage: All your data, including photos and logs, is stored securely in your personal CloudKit account.
//                        - Skinalyze does not store or access your data directly on external servers.
//                        - You have full control over your data in CloudKit and can manage it through your Apple ID account.
//                        """)
//                    }
//                    
//                    Group {
//                        SectionTitle("4. Data Sharing")
//                        Text("We do not share your personal data with third parties. Aggregated, anonymized data (not linked to individual users) may be used to improve our services.")
//                        
//                        SectionTitle("5. Data Security")
//                        Text("""
//                        We implement the following measures to secure your data:
//                        
//                        - Data is encrypted and securely stored in CloudKit, managed by Apple.
//                        - Access to your CloudKit account is protected by your Apple ID credentials.
//                        - Skinalyze employs industry-standard security protocols to ensure the integrity of data during transmission.
//                        """)
//                        
//                        SectionTitle("6. Your Rights")
//                        Text("""
//                        As a user, you have the following rights regarding your data:
//                        
//                        - Access: View the data stored in your CloudKit account.
//                        - Delete: Delete your photos, logs, or other data directly from your account.
//                        - Withdraw Consent: Stop using the app at any time and remove the app's access to your CloudKit account.
//                        """)
//                    }
//                    
//                    Group {
//                        SectionTitle("7. Cookies and Tracking")
//                        Text("Skinalyze does not use cookies or external tracking technologies.")
//                        
//                        SectionTitle("8. Changes to This Privacy Policy")
//                        Text("We may update this Privacy Policy from time to time. Any changes will be communicated through app updates or email notifications.")
//                        
//                        SectionTitle("9. Contact Us")
//                        Text("If you have any questions or concerns about this Privacy Policy, please contact us at:")
//                        Text("Email: skinalyze.id@gmail.com")
//                            .foregroundColor(.blue)
//                    }
//                    
//                    Text("By using Skinalyze, you agree to this Privacy Policy and consent to the processing of your data as outlined above.")
//                        .padding(.top, 16)
//                }
//                .padding()
//            }
//            .navigationTitle("Privacy Policy")
//            .navigationBarTitleDisplayMode(.inline)
//        }
//    }
//    
//    // Helper function for section titles
//    private func SectionTitle(_ title: String) -> some View {
//        Text(title)
//            .font(.headline)
//            .bold()
//            .padding(.top, 8)
//    }
//}
