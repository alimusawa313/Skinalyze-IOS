
import SwiftUI

struct ProfileView: View {
    
    @EnvironmentObject var router: Router
    
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userAge") private var userAge: Int = 0 // Change to Int
    @AppStorage("userGender") private var userGender: String = ""
    @AppStorage("skinType") private var skinType: String = ""
    @AppStorage("skinSensitivity") private var skinSensitivity: String = ""
    @AppStorage("useSkincare") private var useSkincare: String = ""
    
    let skinTypeArray = ["Oily", "Dry", "Combination"]
    let skinSensitivityArray = ["Very Sensitive", "Only Sometimes", "Not Sensitive"]
    
    var body: some View {
            VStack{
                Divider()
                    .padding(.bottom)
                NavigationLink(destination: EditProfileView()) {
                    HStack {
                        Group {
                            Image("Maskot")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 40)
                                .padding()
                        }
                        .background(userGender == "Female" ? .pink.opacity(0.2) : .blue)
                        .cornerRadius(200)
                        .frame(width: 60, height: 60)
                        .padding(.trailing)
                        
                        Text(userName)
                            .fontWeight(.semibold)
                            .font(.system(size: 18))
                            .foregroundColor(Color("textPrimary"))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.forward")
                            .fontWeight(.semibold)
                            .font(.title3)
                    }
                    .padding()
                    .background(Color("ProfileClr"))
                    .cornerRadius(10)
                    .foregroundColor(.black)
                }

                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color("brownSecondary"), lineWidth: 1)
                )
                .padding(.bottom, 20)

                VStack(alignment:.leading){
                    Text("My Skin")
                        .fontWeight(.semibold)
                        .font(.system(size: 20))
                    VStack(spacing: 0) {
//                         Skin type Row
                        HStack {
                            Text("Skin Type")
                                .font(.system(size: 16))
                            Spacer()
                            Picker("", selection: $skinType) {
                                ForEach(skinTypeArray, id: \.self) {
                                    Text($0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle()) // Menampilkan opsi sebagai menu
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                        }
                        .padding()
                        .background(Color("TextReverse"))
                        
                        Divider()
                            .padding(.leading)
                        
                        // Skin sensi Row
                        HStack {
                            Text("Skin Sensitivity")
                                .font(.system(size: 16))
                            Spacer()
                            Picker("", selection: $skinSensitivity) {
                                ForEach(skinSensitivityArray, id: \.self) {
                                    Text($0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle()) // Menampilkan opsi sebagai menu
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                        }
                        .padding()
                    }
                    .background(Color("TextReverse")) // Sesuaikan dengan latar belakang
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("textPrimary"), lineWidth: 1) // Border luar abu-abu tipis
                    )
                }
                .padding(.bottom, 20)
                VStack(alignment:.leading){
                    Text("Product Used")
                        .fontWeight(.semibold)
                        .font(.system(size: 20))
//                    NavigationLink(destination: ProductUsedView(isFromStartup: false)){
                        VStack(spacing: 0) {
                            HStack {
                                Text("Saved Products")
                                    .font(.system(size: 16))
                                Spacer()
                                Image(systemName: "chevron.forward")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color("TextReverse"))
                        }
                        .background(Color("TextReverse")) // Sesuaikan dengan latar belakang
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("textPrimary"), lineWidth: 1) // Border luar abu-abu tipis
                            
                        )
                        .onTapGesture {
                            router.navigate(to: .prodUsed(isFromStartup: false))
                        }
//                    }
                }
                Spacer()
            }
            
            .padding(.horizontal)
            .background(Color("splashScreen"))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            
        }
    }


//#Preview {
//    NavigationView{
//        ProfileView()
//    }
//}

#Preview{
    ProfileView()
}
