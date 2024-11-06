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
    
    @State private var currentIndex = 0
    
    
    var body: some View {
        ZStack {
            
            VStack {
                TabView() {
                    ForEach(images, id: \.self) { index in
                        Image(uiImage: index)
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .tag(index)
                    }
                }
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                
                Spacer()
                
                
                VStack(spacing: 16){
                    
                    Button{
                        router.navigate(to: .anlyzResultView(images: images))
                    }label: {
                        HStack {
                            Spacer()
                            Text("Use Picture")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "6F5750")))
                    }
                    Button{
                        router.navigateBack()
                    }label: {
                        HStack {
                            Spacer()
                            Text("Retake")
                                .font(.headline)
                                .foregroundStyle(Color(hex: "6F5750"))
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "DCD2C9")))
                    }
                }
                .padding()
                
                Spacer()
            }
            
        }
    }
}

//#Preview {
//    CapturedImagesView(images: [.imageTest])
//}
