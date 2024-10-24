//
//  CameraSheetTutor.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/15/24.
//

import SwiftUI

struct CameraSheetTutor: View {
    var doSomething: Void
    var body: some View {
        VStack(alignment:.center){
            Text("Analyze Skin Condition").bold()
            
            Divider()
            
            HStack{
                Text("Scan Tips").bold()
                Spacer()
            }
            
            HStack{
                Image("lightbulb")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 43, height: 36)
                    .padding()
                
                Text("Ensure bright light source for the best scan results.")
                Spacer()
            }
            
            HStack{
                Image("prsn")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 43, height: 36)
                    .padding()
                
                Text("Align your face within the provided border.")
                Spacer()
            }
            
            HStack{
                Image("checkmarktriangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 43, height: 36)
                    .padding()
                
                Text("Follow the prompts to capture your face from the right, left, and front angles.")
                Spacer()
            }
            
            Button{
                doSomething
            }label: {
                HStack {
                    Spacer()
                    Text("Start Analyze")
                        .font(.headline)
                        .padding()
                    Spacer()
                }
                .foregroundStyle(.white)
                .background(Capsule().foregroundStyle(Color("brownSecondary")))
            }
            .padding(.vertical)
        }
        .padding()
    }
}

//#Preview {
//    CameraSheetTutor()
//}
