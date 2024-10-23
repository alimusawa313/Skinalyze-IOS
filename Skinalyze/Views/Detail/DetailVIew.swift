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
                    
                    
                }.font(.subheadline)
                    .bold()
                
                
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        if let image = images[index] {
                            Image(uiImage: image.toImage()!)
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
                
                if selectedLogs.geaScale > 0{
                    AcneRowItem(title: "Skin Concern", acne: acneTypesWithCounts)
                }
                
                
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
    
    private var acneTypesWithCounts: [Acne] {
            // Define your acne types (similar to ResultViewModel)
            let acneTypes = [
                Acne(name: "Blackheads", description: "Your scan detected moderate acne, including the presence of blackheads. Blackheads are tiny open bumps filled with oil and dead skin, giving them a dark appearance.", countKey: "blackheads"),
                Acne(name: "Papules", description: "Your scan detected the presence of papules. Papules are small, solid bumps caused by oil, bacteria, and hormones. Unlike other acne, they don't have a pus-filled tip, but they can still feel irritated.", countKey: "papules"),
                Acne(name: "Pustules", description: "Your scan detected the presence of pustules. Pustules are small white bumps filled with fluid or pus, often surrounded by redness. These bumps may get bigger, but with the right care, you can manage them effectively.", countKey: "pustules"),
                Acne(name: "Whiteheads", description: "Your scan detected the presence of whiteheads. Whiteheads are closed bumps formed when oil and dead skin clog pores. While they're a common form of acne, they can be treated to prevent future breakouts.", countKey: "whiteheads"),
                Acne(name: "Nodules", description: "Your scan detected the presence of nodules. Nodules are firm, deep lumps that can be larger and more painful than other types of acne. They require targeted care for reduction and healing.", countKey: "nodules"),
                Acne(name: "Dark Spots", description: "Your scan detected the presence of dark spots. Dark spots, or hyperpigmentation, are caused by excess melanin production. They can appear due to sun exposure or aging, but with the right care, they can be lightened over time.", countKey: "dark spot")
            ]
            
            return acneTypes.map { acne in
                var updatedAcne = acne
                updatedAcne.count = selectedLogs.acneCounts[acne.countKey.lowercased(), default: 0]
                return updatedAcne
            }
        }
}


//#Preview {
//    DetailVIew()
//}
