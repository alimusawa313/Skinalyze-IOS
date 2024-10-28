//
//  AboutToScanView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/17/24.
//

import SwiftUI

struct AboutToScanView: View {
    
    @Binding var showSheet: Bool
    @EnvironmentObject var router: Router
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Image("ProfileAtas")
                        .resizable()
                        .frame(width: UIScreen.main.bounds.width, height: 250)
                    Spacer()
                }
                .padding(.top, 25)
                VStack(alignment: .leading, spacing: 20){
                    HStack {
                        Spacer()
                        Image(.maskotScan)
                            .resizable()
                            .frame(width: 250, height: 220)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text("Scan your skin conditions!")
                        .font(.title)
                        .bold()
                    
                    Text("Get a detailed analysis of your skin, including severity level and recommended ingredients")
                        .font(.system(size: 13, weight: .light))
                    
                    
                    VStack(alignment:.center){
                        
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
                            showSheet.toggle()
//                            router.navigate(to: .camScanView)
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
                        Spacer()
                    }
                    
                    //
                }
                .padding()
                .navigationTitle("Analyze Skin Condition")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    AboutToScanView(showSheet: .constant(true))
}
