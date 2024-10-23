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
                
                AboutToScanView()
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

//        TabView(selection: $selection) {
//            NavigationStack(path: $path) {
//                LogView()
//                    .navigationBarTitle("FaceLog")
//                    .navigationBarTitleDisplayMode(.inline)
////                    .navigationDestination(for: String.self) { view in
////                        if view == "CameraScanView" {
////                            CameraScanView(path: $path)
////                        } else if view == "ResultView" {
////                            AnalyzedResultView(path: $path)
////                        }
////                    }
//            }
//            .tabItem {
//                Image(systemName: "list.bullet.clipboard")
//                Text("FaceLog")
//            }
//            .tag(0)
//
//            NavigationStack {
//                EmptyView()
//                NavigationLink(destination: CameraScanView()) {
//                    Text("Open Camera Scan")
//                }
//            }
//            .tabItem {
//                Image(systemName: "camera.viewfinder")
//                Text("Scan")
//            }
//            .tag(1)
//
//            .onAppear {
//                self.showCameraScan = true
//            }
//            .navigationDestination(isPresented: $showCameraScan) {
//                NavigationView {
//                    CameraScanView()
//                        .navigationBarHidden(true)
//                        .onDisappear {
//                            self.selection = 0
//                        }
//                }
//            }
//
//            NavigationView {
//                ProfileView()
//                    .navigationBarTitle("Profile")
//            }
//            .tabItem {
//                Image(systemName: "person")
//                Text("Profile")
//            }
//            .tag(2)
//        }

//=======



//                NavigationStack {
//                    EmptyView()
//                    NavigationLink(destination: CameraScanView()) {
//                        Text("Open Camera Scan")
//                    }
//                }
//                .tabItem {
//                    Image(systemName: "camera.viewfinder")
//                    Text("Scan")
//                }
//                .tag(1)
//                .onAppear {
//                    self.showCameraScan = true
//                }
//                .navigationDestination(isPresented: $showCameraScan) {
//                    NavigationView {
//                        CameraScanView()
//                            .navigationBarHidden(true)
//                            .onDisappear {
//                                self.selection = 0
//                            }
//                    }
//
//                }
