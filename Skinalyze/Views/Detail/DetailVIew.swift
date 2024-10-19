//
//  DetailVIew.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/18/24.
//

import SwiftUI

struct DetailVIew: View {
    
    
    var selectedLogs: Result
    
    @EnvironmentObject var router: Router
    
    @ObservedObject var viewmodel: ResultViewModel = ResultViewModel()
    @State private var currentDate = Date()
    
    @State private var currentIndex = 0
    
    @State private var selectedView = 0
    
//    private var acneTypesWithCounts: [Acne] {
//        viewmodel.acneTypes.map { acne in
//            var updatedAcne = acne
//            updatedAcne.count = viewmodel.acneCounts[acne.countKey.lowercased(), default: 0]
//            return updatedAcne
//        }
//    }
    
    @AppStorage("skinType") private var skinType: String = ""
    @AppStorage("skinSensitivity") private var skinSensitivity: String = ""
    
    var body: some View {
        
        let images: [String?] = [selectedLogs.analyzedImages1, selectedLogs.analyzedImages2, selectedLogs.analyzedImages3]
        
        ScrollView{
            
            VStack{
                
                HStack(alignment: .center){
                    
                    
                    Text("\(selectedLogs.currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                    
                    //                    Text("at")
                    //                    Text("currentDate, format: .dateTime.hour().minute()")
                    
                }.font(.subheadline)
                    .bold()
                
//                TabView(selection: $currentIndex) {
//                    ForEach(images.indices, id: \.self) { index in
//                        Image(uiImage: images[0]!.toImage()!)
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
//                            .tag(index)
//                    }
//                    
//                    .frame(height: UIScreen.main.bounds.height / 2)
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
//                }
                
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        if let image = images[index] {
                            Image(uiImage: images[0]!.toImage()!)
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                                .tag(index)
                        } else {
                            // You can add a placeholder image or a message here
                            Text("No image available")
                                .tag(index)
                        }
                    }
                }.frame(height: UIScreen.main.bounds.height / 2)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                
                
                //                Image(uiImage: images[0]!.toImage()!)
                
                
                
                HStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .frame(width: 8)
                            .foregroundColor(index == currentIndex ? .primary : .secondary)
                    }
                }
                .padding(5)
                .background(Capsule().foregroundStyle(.tertiary))
                
                HStack {
                    Text("Severity Level")
                        .font(.title3)
                        .bold()
                    Spacer()
                }.padding(.vertical)
                
                HStack{
                    Text("Healthy")
                    Spacer()
                    Text("Severe")
                }.font(.footnote)
                    .padding(.bottom, -15)
                
                
                SeverityIndicator(acneLevelScale: selectedLogs.geaScale)
                
                let severityLevel = AcneSeverityLevel(rawValue: selectedLogs.geaScale)!
                Text(severityDescriptions[severityLevel.rawValue]!)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
                
                
                // Display counts for each acne type
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(selectedLogs.acneCounts.keys.sorted().filter { selectedLogs.acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: "74574F").opacity(0.8))
                                .overlay(
                                    Text("\(key.capitalized) (\(selectedLogs.acneCounts[key] ?? 0))")
                                        .bold()
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                )
                                .frame(width: 120, height: 40)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -15)
                
//                if selectedLogs.geaScale > 0{
//                    AcneRowItem(title: "Skin Concern", acne: acneTypesWithCounts)
//                }
                
                
                Picker("", selection: $selectedView) {
                    Text("Ingridients").tag(0)
                    Text("Product Used").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical)
                
                if selectedView == 0 {
                    VStack {
                        RowItemHolder(title: "Ingredients Recommendations", ingredients: $viewmodel.ingredients)
                            .padding(.bottom)
                        RowItemHolder(title: "Ingredients You Should Avoid", ingredients: $viewmodel.ingredientsNotRec)
                        
                    }
                } else {
                    ProductUsedView(isFromStartup: false)
                }
                
                
            }
            .padding()
        }
        .navigationTitle("Scan Result")
        
    }
}


//#Preview {
//    DetailVIew()
//}
