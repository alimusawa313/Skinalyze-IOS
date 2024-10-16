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
    
    
    var body: some View {
            
            TabView(selection: $selection) {
                LogView()
                    .navigationBarTitle("FaceLog")
                    .navigationBarTitleDisplayMode(.inline)
                    .tabItem {
                        Image(systemName: "list.bullet.clipboard")
                        Text("FaceLog")
                    }
                    .tag(0)
                
                
                temp(selection: $selection)
//                .onAppear{
//                    router.navigate(to: .camScanView)
//                }
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
