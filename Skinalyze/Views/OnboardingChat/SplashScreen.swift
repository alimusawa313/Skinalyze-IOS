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
                    
//                    Text("Effective Date: [Insert Date]")
//                        .italic()
//                        .padding(.bottom, 16)
                    
                    Group {
                        Text("At Skinalyze, your privacy is our top priority. This Privacy Policy explains how we collect, use, and protect your data when you use our application. By using Skinalyze, you agree to the practices outlined in this document.")
                        
                        SectionTitle("1. Data We Collect")
                        Text("""
                        When you use Skinalyze, we may collect the following types of data:
                        
                        - Facial Photos: Uploaded for skin analysis purposes.
                        - Skincare Product Information: Saved products and logs to track your progress.
                        - Usage Data: Includes app activity, feature interactions, and analytics to improve the app experience.
                        """)
                        
                        SectionTitle("2. How We Use Your Data")
                        Text("""
                        Your data is used for the following purposes:
                        
                        - To analyze your facial skin and provide ingredient recommendations.
                        - To save and organize your skincare product details.
                        - To track and display your skin progress over time.
                        - To improve our app through aggregated, anonymized analytics (does not include personal data).
                        """)
                        
                        SectionTitle("3. Where Your Data is Stored")
                        Text("""
                        - CloudKit Storage: All your data, including photos and logs, is stored securely in your personal CloudKit account.
                        - Skinalyze does not store or access your data directly on external servers.
                        - You have full control over your data in CloudKit and can manage it through your Apple ID account.
                        """)
                    }
                    
                    Group {
                        SectionTitle("4. Data Sharing")
                        Text("We do not share your personal data with third parties. Aggregated, anonymized data (not linked to individual users) may be used to improve our services.")
                        
                        SectionTitle("5. Data Security")
                        Text("""
                        We implement the following measures to secure your data:
                        
                        - Data is encrypted and securely stored in CloudKit, managed by Apple.
                        - Access to your CloudKit account is protected by your Apple ID credentials.
                        - Skinalyze employs industry-standard security protocols to ensure the integrity of data during transmission.
                        """)
                        
                        SectionTitle("6. Your Rights")
                        Text("""
                        As a user, you have the following rights regarding your data:
                        
                        - Access: View the data stored in your CloudKit account.
                        - Delete: Delete your photos, logs, or other data directly from your account.
                        - Withdraw Consent: Stop using the app at any time and remove the app's access to your CloudKit account.
                        """)
                    }
                    
                    Group {
                        SectionTitle("7. Cookies and Tracking")
                        Text("Skinalyze does not use cookies or external tracking technologies.")
                        
                        SectionTitle("8. Changes to This Privacy Policy")
                        Text("We may update this Privacy Policy from time to time. Any changes will be communicated through app updates or email notifications.")
                        
                        SectionTitle("9. Contact Us")
                        Text("If you have any questions or concerns about this Privacy Policy, please contact us at:")
                        Text("Email: skinalyze.id@gmail.com")
                            .foregroundColor(.blue)
                    }
                    
                    Text("By using Skinalyze, you agree to this Privacy Policy and consent to the processing of your data as outlined above.")
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
