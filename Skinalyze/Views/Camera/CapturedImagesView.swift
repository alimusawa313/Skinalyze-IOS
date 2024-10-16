//
//  CapturedImagesView.swift
//  FaceTracking
//
//  Created by Ali Haidar on 10/3/24.
//

import SwiftUI

struct CapturedImagesView: View {
    let images: [UIImage]
    
    @State private var moveToAnalyze: Bool = false
    
    @EnvironmentObject var router: Router

    var body: some View {
        VStack {
            Text("Captured Images")
                .font(.title)
                .padding()
            
            TabView() {
                ForEach(images, id: \.self) { index in
                    Image(uiImage: index)
                        .resizable()
//                                .scaledToFit()
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 1.8)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .tag(index)
                }
            }
            .frame(height: UIScreen.main.bounds.height / 1.8)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            
            Button("Lanjutkan") {
//                moveToAnalyze.toggle()
                router.navigate(to: .anlyzResultView(images: images))
            }
            .padding()
            
            Button("Selfie Ulang") {
            }
        }
        .padding()
//        .navigationDestination(isPresented: $moveToAnalyze){
//            AnalyzedResultView(images: images)
////            AnalyzeView(selectedImages: images)
//        }
    }
}


