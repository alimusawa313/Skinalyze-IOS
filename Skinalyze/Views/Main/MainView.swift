//
//  MainView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/14/24.
//

import SwiftUI

struct MainView: View {
    @State private var isTabBarHidden = false
    @State private var selection = 0
    @State private var showCameraScan = false
    @State private var path: [String] = []
    @State private var oldSelectedItem = 0
    
    
    @EnvironmentObject var router: Router
    
    
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userAge") private var userAge: Int = 0 // Change to Int
    @AppStorage("userGender") private var userGender: String = ""
    @AppStorage("skinType") private var skinType: String = ""
    @AppStorage("skinSensitivity") private var skinSensitivity: String = ""
    @AppStorage("useSkincare") private var useSkincare: String = ""
    
    var body: some View {
        
        if (userName.isEmpty && userAge == 0 && userGender.isEmpty && skinType.isEmpty && skinSensitivity.isEmpty && useSkincare.isEmpty) {
            SplashScreen()
        } else{
            TabView(selection: $selection) {
                LogView(isTabBarHidden: $isTabBarHidden)
                    .navigationBarTitle("Face Log")
                    .navigationBarTitleDisplayMode(.inline)
                    .tabItem {
                        Image(systemName: "list.bullet.clipboard")
                        Text("Face Log")
                    }
                    .tag(0)
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
                
                //                AboutToScanView()
                Text("")
                    .tabItem {
                        Image(systemName: "camera.viewfinder")
                        Text("Scan")
                    }
                    .tag(1)
                
                
                
                NavigationView {
                    ProfileView()
                        .navigationBarTitle("Profile")
                }
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
                .tag(2)
            }
            .onChange(of: selection) {
                if 1 == selection {
                    self.showCameraScan = true
                    router.navigate(to: .camScanView)
                } else {
                    self.oldSelectedItem = $0
                }
                self.selection = self.oldSelectedItem
            }
//            .sheet(isPresented: $showCameraScan, onDismiss: {
//                self.selection = self.oldSelectedItem
//            }) {
//                AboutToScanView(showSheet: $showCameraScan)
//            }
        }
    }
}


#Preview {
    MainView()
}

struct temp: View {
    @EnvironmentObject var router: Router
    
    @Binding var selection: Int
    var body: some View{
        VStack{
            
        }.onAppear{
            selection = 0
            router.navigate(to: .camScanView)
        }
    }
}
