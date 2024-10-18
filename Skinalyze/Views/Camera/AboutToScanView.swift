//
//  AboutToScanView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/17/24.
//

import SwiftUI

struct AboutToScanView: View {
    
    @State private var showSheet = false
    @EnvironmentObject var router: Router
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20){
                Spacer()
                HStack {
                    Spacer()
                    Image(.maskotScan)
                        .resizable()
                        .frame(width: UIScreen.main.bounds.width - 100, height: UIScreen.main.bounds.width - 100)
                    Spacer()
                }
                
                Spacer()
                
                Text("Get Your Skin\nCondition Scan")
                    .font(.largeTitle)
                    .bold()
                
                Text("Get Your Skin Condition Scan")
                    .font(.headline)
                
                Button{
                    showSheet.toggle()
                }label: {
                    HStack{
                        Spacer()
                        Text("Scan My Face")
                            .bold()
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "74574F")))
                }
            }
            .padding()
            .navigationTitle("Face Scan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSheet) {
                
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
                        showSheet.toggle()
                        router.navigate(to: .camScanView)
                    }label: {
                        HStack {
                            Spacer()
                            Text("Start Analyze")
                                .font(.headline)
                                .padding()
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .background(Capsule().foregroundStyle(Color(hex: "74574F")))
                    }
                    .padding(.vertical)
                }
                .padding()
                .presentationDetents([.medium])
                //            .interactiveDismissDisabled()
            }
        }
    }
}

#Preview {
    AboutToScanView()
}
