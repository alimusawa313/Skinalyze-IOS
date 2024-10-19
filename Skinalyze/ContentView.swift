//
//  ContentView.swift
//  Skinalyze
//
//  Created by Heical Chandra on 23/09/24.
//

import SwiftUI

struct ContentView: View {
    
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userAge") private var userAge: Int = 0 // Change to Int
    @AppStorage("userGender") private var userGender: String = ""
    @AppStorage("skinType") private var skinType: String = ""
    @AppStorage("skinSensitivity") private var skinSensitivity: String = ""
    @AppStorage("useSkincare") private var useSkincare: String = ""
    
    var body: some View {
        
//        if (userName.isEmpty && userAge == 0 && userGender.isEmpty && skinType.isEmpty && skinSensitivity.isEmpty && useSkincare.isEmpty) {
//            SplashScreen()
//        } else{
            MainView()
//        }
//        SplashScreen()
        
    }
}

//#Preview {
//    ContentView()
//}

//enum ViewType: Hashable {
////    case second
////    case third(message: String)
//    case log
//    case camScanView
//    case capturedImagesView(images: [UIImage])
//    case anlyzResultView(images: [UIImage])
//}
