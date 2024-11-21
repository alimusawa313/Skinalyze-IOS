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
                        .zIndex(0)
                    Spacer()
                }
//                .padding(.top, 25)
                
                ScrollView{
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
                        
                        Text("Disclaimer: ")
                            .bold().font(.footnote).foregroundStyle(.red) +
                        Text("This app is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a doctor for health-related decisions.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
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
                            
                            HStack{
                                
                            }.frame(height: 100)
                            Spacer()
                        }
                        
                        
                        
                        //
                    }.padding()
                }
                
                VStack{
                    Spacer()
                    
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
                        .background(Capsule().foregroundStyle(Color(hex: "6F5750")))
                    }
                    .padding()
                }
            }
            .navigationTitle("Analyze Skin Condition")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AboutToScanView(showSheet: .constant(true))
}
