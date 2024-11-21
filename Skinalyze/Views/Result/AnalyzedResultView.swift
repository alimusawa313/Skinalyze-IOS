//
//  AnalyzedResultView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/15/24.
//

import SwiftUI
import Vision
import CoreML
import SwiftData

struct AnalyzedResultView: View {
    
    
    @EnvironmentObject var router: Router
    
    @ObservedObject var viewmodel: ResultViewModel = ResultViewModel()
    @State private var currentDate = Date()
    
    
    @State private var selectedView = 0
    
    @State private var currentIndex = 0
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var result: [Result]
    
    @State var selectedCardIndex = 0
    
    @State private var isShowingBoundingBoxes = false
//    @State private var visibleAcneTypes: Set<String> = Set(["blackheads", "dark spot", "nodules", "papules", "pustules", "whiteheads"])
    @State private var visibleAcneTypes: Set<String> = []
    
    @State private var showSheet: Bool = false
    @State private var showSheetInfo: Bool = false
    
    @State var images: [UIImage] = []
    
    @AppStorage("cleanserUsedID") private var cleanserUsedID: Int = 0
    @AppStorage("tonerUsedID") private var tonerUsedID: Int = 0
    @AppStorage("moisturizerUsedID") private var moisturizerUsedID: Int = 0
    @AppStorage("sunscreenUsedID") private var sunscreenUsedID: Int = 0
    
    private var acneTypesWithCounts: [Acne] {
        viewmodel.acneTypes.map { acne in
            var updatedAcne = acne
            updatedAcne.count = viewmodel.acneCounts[acne.countKey.lowercased(), default: 0]
            return updatedAcne
        }
    }
    
    
    var body: some View {
        ZStack {
            Color("splashScreen").ignoresSafeArea()
            ScrollView{
                
                VStack{
                    
                    HStack(alignment: .center){
                        
                        
                        Text(currentDate, format: .dateTime.day().month().year())
                        
                        Text("at")
                        Text(currentDate, format: .dateTime.hour().minute())
                        
                    }.font(.subheadline)
                        .bold()
                    
                    if viewmodel.isLoading {
                        ProgressView("Analyzing Images...")
                    } else if !viewmodel.analyzedImages.isEmpty {
                        TabView(selection: $currentIndex) {
                            ForEach(viewmodel.analyzedImages.indices, id: \.self) { index in
                                ZStack {
                                    Image(uiImage: viewmodel.analyzedImages[index])
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    Image(uiImage: filteredBoundingBoxImage(at: index))
                                        .resizable()
                                        .scaledToFit()
                                        .allowsHitTesting(false)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: UIScreen.main.bounds.height / 2)
                    } else if !images.isEmpty {
                        TabView(selection: $currentIndex) {
                            ForEach(images.indices, id: \.self) { index in
                                Image(uiImage: images[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                                    .tag(index)
                            }
                        }
                        .frame(height: UIScreen.main.bounds.height / 2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .onAppear {
                            analyzeImages()
                        }
                    } else {
                        ZStack{
                            
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: .infinity, height: UIScreen.main.bounds.height / 2)
                            
                            Text("No images available").foregroundStyle(.white)
                        }
                    }
                    
                    HStack {
                        ForEach(0..<3) { index in
                            Circle()
                                .frame(width: 8)
                                .foregroundColor(index == currentIndex ? .primary : .secondary)
                        }
                    }
                    .padding(5)
                    .background(Capsule().foregroundStyle(.tertiary))
                    
                    //                Toggle("Show Bounding Boxes", isOn: $isShowingBoundingBoxes)
                    //                    .padding()
                    
                    
                    
                    HStack {
                        Text("Severity Level")
                            .font(.title3)
                            .bold()
                        Button{
                            showSheet.toggle()
                        }label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color("textPrimary"))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    
                    HStack {
                        Text("Healthy")
                        Spacer()
                        Text("Severe")
                    }
                    .font(.footnote)
                    .padding(.bottom, -20)
                    
                    SeverityIndicator(acneLevelScale: viewmodel.geaScale)
                    
                    let severityLevel = AcneSeverityLevel(rawValue: viewmodel.geaScale)!
                    Text(severityDescriptions[severityLevel.rawValue]!)
                        .foregroundStyle(.secondary)
                        .font(.custom("", size: 15))
                        .padding(.vertical, 5)
                    
                    
                    // Display counts for each acne type
                    //                ScrollView(.horizontal, showsIndicators: false) {
                    //                    HStack(spacing: 5) {
                    //                        ForEach(viewmodel.acneCounts.keys.sorted().filter { viewmodel.acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                    //                            RoundedRectangle(cornerRadius: 10)
                    //                                .fill(Color("capsuleBg").opacity(0.8))
                    //                                .overlay(
                    //                                    Text("\(key.capitalized) (\(viewmodel.acneCounts[key] ?? 0))")
                    //                                        .bold()
                    //                                        .font(.footnote)
                    //                                        .foregroundColor(.white)
                    //                                )
                    //                                .frame(width: 120, height: 40)
                    //                        }
                    //                    }
                    //                    .padding(.horizontal, 16)
                    //                }
                    //                .padding(.horizontal, -15)
                    
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            // Button to select/deselect all acne types
                            Button(action: {
                                
                                visibleAcneTypes = Set(viewmodel.acneCounts.keys.sorted())
                            }) {
                                Text("Select All")
                                    .foregroundStyle(Color("textPrimary"))
                                    .padding(8)
                                    .background(Color("capsuleBg"))
                                    .cornerRadius(10)
                            }
                            .padding(5)
                            
                            // Existing buttons for individual acne types
                            ForEach(viewmodel.acneCounts.keys.sorted().filter { viewmodel.acneCounts[$0] ?? 0 > 0 }, id: \.self) { acneType in
                                Button(action: {
                                    // Set the selected acne type as the only visible type
                                    visibleAcneTypes = [acneType]
                                }) {
                                    HStack {
                                        Text(acneType.capitalized)
                                            .foregroundStyle(Color("textPrimary"))
                                    }
                                    .padding(8)
                                    .background(Color("capsuleBg"))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(visibleAcneTypes.contains(acneType) ? Color("capsuleBorderColor") : Color.clear, lineWidth: 2)
                                    )
                                }
                                .padding(5)
                            }
                        }
                        .padding(.bottom)
                    }
                    
                    if viewmodel.geaScale > 0{
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
                            Button{
                                showSheetInfo.toggle()
                            }label: {
                                HStack {
                                    Spacer()
                                    Text("Click to see from where we get these recommendations from")
                                        .foregroundStyle(.red)
                                    
                                    Spacer()
                                }
                
                            }
                            .padding(.vertical)
                            .buttonStyle(BorderedButtonStyle())
                            
                            RowItemHolder(title: "Ingredients Recommendations", ingredients: $viewmodel.ingredients)
                                .padding(.bottom)
                            RowItemHolder(title: "Ingredients You Should Avoid", ingredients: $viewmodel.ingredientsNotRec)
                            
                            
                            
                        }
                    } else {
                        ProductUsedSaved(cleanserUsedID: cleanserUsedID, tonerUsedID: tonerUsedID, moisturizerUsedID: moisturizerUsedID, sunscreenUsedID: sunscreenUsedID)
                    }
                    
                    
                }
                .padding()
            }
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Call the save function here
                        saveData()
                    }
                }
            }
            .onAppear{
                setInitialVisibleAcneType()
            }
            .sheet(isPresented: $showSheet) {
                sheetView()
                    .presentationDetents([.height(350)])
            }
            .sheet(isPresented: $showSheetInfo) {
                SkinCareRecommendationsSourceView()
//                    .presentationDetents([.height(350)])
            }
        }
    }
    
    
    private func setInitialVisibleAcneType() {
        let availableTypes = viewmodel.acneCounts.keys.sorted().filter { viewmodel.acneCounts[$0] ?? 0 > 0 }
        
        // If there are available types, select all of them
        if !availableTypes.isEmpty {
            visibleAcneTypes = Set(availableTypes) // Ensure all types are selected
        }
    }
    
    func filteredBoundingBoxImage(at index: Int) -> UIImage {
        guard index < viewmodel.boundingBoxImages.count else {
            return UIImage()
        }
        
        // Use all visible types directly from the state
        let visibleTypes = Array(visibleAcneTypes)
        
        // Pass the visible types to the bounding box drawing method
        let filteredImage = viewmodel.drawBoundingBoxes(
            on: viewmodel.analyzedImages[index],
            results: viewmodel.detectedResults[index],
            originalImageSize: viewmodel.analyzedImages[index].size,
            visibleTypes: visibleTypes
        )
        
        return filteredImage
    }
    
//    private func setInitialVisibleAcneType() {
//        let availableTypes = viewmodel.acneCounts.keys.sorted().filter { viewmodel.acneCounts[$0] ?? 0 > 0 }
//        
//        // If there are available types, select the first one
//        if !availableTypes.isEmpty {
//            visibleAcneTypes = [availableTypes.first!]
//        }
//    }
//    
//    func filteredBoundingBoxImage(at index: Int) -> UIImage {
//        guard index < viewmodel.boundingBoxImages.count else {
//            return UIImage()
//        }
//        
//        // If visibleAcneTypes is empty, find the first available acne type
//        let visibleTypes: [String]
//        if visibleAcneTypes.isEmpty {
//            let availableTypes = viewmodel.acneCounts.keys.sorted().filter { viewmodel.acneCounts[$0] ?? 0 > 0 }
//            visibleTypes = availableTypes.isEmpty ? [] : [availableTypes.first!]
//        } else {
//            visibleTypes = Array(visibleAcneTypes)
//        }
//        
//        // Pass the visible types to the bounding box drawing method
//        let filteredImage = viewmodel.drawBoundingBoxes(
//            on: viewmodel.analyzedImages[index],
//            results: viewmodel.detectedResults[index],
//            originalImageSize: viewmodel.analyzedImages[index].size,
//            visibleTypes: visibleTypes
//        )
//        
//        return filteredImage
//    }
    
    func saveData() {
        let imagesBase64 = images.compactMap { $0.base64 }
        let analyzedImagesBase64 = viewmodel.analyzedImages.compactMap { $0.base64 }
        let boundingBoxImagesBase64 = viewmodel.boundingBoxImages.compactMap { $0.base64 }
        
        let result = Result(
            images: imagesBase64,
            selectedCardIndex: selectedCardIndex,
            analyzedImages: analyzedImagesBase64,
            isLoading: viewmodel.isLoading,
            acneCounts: viewmodel.acneCounts,
            geaScale: viewmodel.geaScale,
            currentDate: currentDate,
            boundingBoxImages: boundingBoxImagesBase64,
            cleanserUsedID: self.cleanserUsedID,
            tonerUsedID: self.tonerUsedID,
            moisturizerUsedID: self.moisturizerUsedID,
            sunscreenUsedID: self.sunscreenUsedID
        )
        
        // Insert the result into the model context
        modelContext.insert(result)
        
        // Save the model context
        do {
            router.navigateToRoot()
            try modelContext.save()
            print("Data saved successfully!")
        } catch {
            print("Error saving data: \(error.localizedDescription)")
        }
    }
    
    
    func analyzeImages() {
        viewmodel.analyzedImages.removeAll()
        viewmodel.isLoading = true
        viewmodel.resetAcneCounts() // Reset counts before new analysis
        
        let dispatchGroup = DispatchGroup()
        
        for image in images {
            dispatchGroup.enter()
            viewmodel.detectObjects(in: image) {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            viewmodel.isLoading = false
            viewmodel.calculateGEAScale() // Calculate the GEA Scale after detection
        }
    }
    
}

#Preview {
    AnalyzedResultView()
}


extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
