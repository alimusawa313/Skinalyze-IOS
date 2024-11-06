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
                                .fill(Color("capsuleBg").opacity(0.8))
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
                    Text("Ingredients").tag(0)
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
                    ProductUsedSaved()
                }
                
                
            }
            .padding()
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
        
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




struct ProductUsedSaved: View {
//    var isFromStartup: Bool
    
    @StateObject var viewModel = SkincareProductViewModel()
    @State private var showCleanserSheet = false
    @State private var showTonerSheet = false
    @State private var showMoisturizerSheet = false
    @State private var showSunscreenSheet = false
    @State private var moveToCamScanner = false
    
    @AppStorage("cleanserUsedID") private var cleanserUsedID: Int = 0
    @AppStorage("tonerUsedID") private var tonerUsedID: Int = 0
    @AppStorage("moisturizerUsedID") private var moisturizerUsedID: Int = 0
    @AppStorage("sunscreenUsedID") private var sunscreenUsedID: Int = 0
    
    var body: some View {
        
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Cleanser")
                        .bold()
                    Button(action: { showCleanserSheet.toggle() }) {
                        if cleanserUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("12345")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("12345")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                        } else {
                            // Cari produk berdasarkan cleanserUsedID
                            if let cleanserProduct = viewModel.products.first(where: { $0.product_id == cleanserUsedID }) {
                                ZStack(alignment: .topTrailing) {
                                    VStack {
                                        AsyncImage(url: URL(string: cleanserProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 149, height: 131)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(cleanserProduct.name)
                                                .font(.headline)
                                                .foregroundColor(.black)
                                                .lineLimit(2, reservesSpace: true)
                                            Text(cleanserProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    // Button "X" to delete the product
                                    Button(action: {
                                        cleanserUsedID = 0
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color("brownTest"))
                                            
                                    }
                                }
                            }
                            else {
                                Text("Product not found")
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showCleanserSheet) {
                        ProductSearchView(isPresented: $showCleanserSheet, categoryFilter: "Cleanser", products: viewModel.products)
                    }
                }
                
                
                VStack(alignment:.leading){
                    Text("Toner")
                        .bold()
                    Button(action: { showTonerSheet.toggle() }) {
                        if tonerUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("12345")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("12345")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                        } else {
                            // Cari produk berdasarkan cleanserUsedID
                            if let tonerProduct = viewModel.products.first(where: { $0.product_id == tonerUsedID }) {
                                ZStack(alignment:.topTrailing) {
                                    VStack {
                                        AsyncImage(url: URL(string: tonerProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading) {
                                            Text(tonerProduct.name)
                                                .font(.headline)
                                                .foregroundColor(.black)
                                                .lineLimit(2, reservesSpace: true)
                                            //                                            .truncationMode(.tail)
                                            Text(tonerProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Button(action: {
                                        tonerUsedID = 0
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color("brownTest"))
                                            
                                    }
                                }
                            } else {
                                Text("Product not found")
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showTonerSheet) {
                        ProductSearchView(isPresented: $showTonerSheet, categoryFilter: "Toner", products: viewModel.products)
                    }
                }
            }
            .padding()
            HStack(spacing: 20) {
                VStack(alignment:.leading){
                    Text("Moisturizer")
                        .bold()
                    Button(action: { showMoisturizerSheet.toggle() }) {
                        if moisturizerUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("1")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("1")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                            
                        } else {
                            if let moisturizerProduct = viewModel.products.first(where: { $0.product_id == moisturizerUsedID }) {
                                ZStack(alignment:.topTrailing){
                                    VStack {
                                        AsyncImage(url: URL(string: moisturizerProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                            //                                            .padding()
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            //                                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 7)
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading) {
                                            Text(moisturizerProduct.name)
                                                .font(.headline)
                                                .foregroundColor(.black)
                                                .lineLimit(2, reservesSpace: true)
                                            Text(moisturizerProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Button(action: {
                                        moisturizerUsedID = 0
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color("brownTest"))
                                            
                                    }
                                }
                            } else {
                                Text("Product not found") // Fallback jika ID tidak sesuai
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showMoisturizerSheet) {
                        ProductSearchView(isPresented: $showMoisturizerSheet, categoryFilter: "Moisturizer", products: viewModel.products)
                    }
                }
                VStack(alignment:.leading){
                    Text("Sunscreen")
                        .bold()
                    Button(action: { showSunscreenSheet.toggle() }) {
                        if sunscreenUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("12345")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("12345")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                        } else {
                            // Cari produk berdasarkan cleanserUsedID
                            if let sunscreenProduct = viewModel.products.first(where: { $0.product_id == sunscreenUsedID }) {
                                ZStack(alignment:.topTrailing){
                                    VStack {
                                        AsyncImage(url: URL(string: sunscreenProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                            //                                            .padding()
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            //                                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 7)
                                            
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading) {
                                            Text(sunscreenProduct.name)
                                                .font(.headline)
                                                .foregroundColor(.black)
                                                .lineLimit(2, reservesSpace: true)
                                            Text(sunscreenProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Button(action: {
                                        sunscreenUsedID = 0
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color("brownTest"))
                                            
                                    }
                                }
                            } else {
                                Text("Product not found") // Fallback jika ID tidak sesuai
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showSunscreenSheet) {
                        ProductSearchView(isPresented: $showSunscreenSheet, categoryFilter: "Sunscreen", products: viewModel.products)
                    }
                }
            }
            .padding()
            Spacer()
        .padding(.top, 50 )
        .onAppear {
            viewModel.loadJSON()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
//#Preview {
//    DetailVIew()
//}
