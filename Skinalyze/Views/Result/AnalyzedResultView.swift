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
    @State private var visibleAcneTypes: Set<String> = Set(["blackheads", "dark spot", "nodules", "papules", "pustules", "whiteheads"])
    
    
    
    @State var images: [UIImage] = []
    
    private var acneTypesWithCounts: [Acne] {
        viewmodel.acneTypes.map { acne in
            var updatedAcne = acne
            updatedAcne.count = viewmodel.acneCounts[acne.countKey.lowercased(), default: 0]
            return updatedAcne
        }
    }
    
    
    var body: some View {
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
                            //                            Image(uiImage: viewmodel.analyzedImages[index])
                            //                                .resizable()
                            //                                .scaledToFit()
                            //                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                            //                                .tag(index)
                            
                            //                            ZStack {
                            //                                Image(uiImage: viewmodel.analyzedImages[index])
                            //                                    .resizable()
                            //                                    .scaledToFit()
                            //                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                            //
                            //                                if isShowingBoundingBoxes {
                            //                                    Image(uiImage: viewmodel.boundingBoxImages[index])
                            //                                        .resizable()
                            //                                        .scaledToFit()
                            //                                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                            //                                        .allowsHitTesting(false)
                            //                                }
                            //                            }
                            //                            .tag(index)
                            
                            
                            ZStack {
                                Image(uiImage: viewmodel.analyzedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                                
                                Image(uiImage: filteredBoundingBoxImage(at: index))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                                    .allowsHitTesting(false)
                            }
                            .tag(index)
                        }
                    }
                    .frame(height: UIScreen.main.bounds.height / 2)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
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
                    Spacer()
                }.padding(.vertical)
                
                HStack{
                    Text("Healthy")
                    Spacer()
                    Text("Severe")
                }.font(.footnote)
                    .padding(.bottom, -15)
                
                
                SeverityIndicator(acneLevelScale: viewmodel.geaScale)
                
                let severityLevel = AcneSeverityLevel(rawValue: viewmodel.geaScale)!
                Text(severityDescriptions[severityLevel.rawValue]!)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
                
                
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
                        ForEach(["blackheads", "dark spot", "nodules", "papules", "pustules", "whiteheads"], id: \.self) { acneType in
                            Button(action: {
                                if visibleAcneTypes.contains(acneType) {
                                    visibleAcneTypes.remove(acneType)
                                } else {
                                    visibleAcneTypes.insert(acneType)
                                }
                            }) {
                                HStack {
                                    Image(systemName: visibleAcneTypes.contains(acneType) ? "checkmark.square.fill" : "square")
                                    Text(acneType.capitalized)
                                }
                                .padding(8)
                                .background(visibleAcneTypes.contains(acneType) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    // Call the save function here
                    saveData()
                }
            }
        }
    }
    
    func filteredBoundingBoxImage(at index: Int) -> UIImage {
        guard index < viewmodel.boundingBoxImages.count else {
            return UIImage()
        }
        
        // Pass the visible types to the bounding box drawing method
        let filteredImage = viewmodel.drawBoundingBoxes(
            on: viewmodel.analyzedImages[index],
            results: viewmodel.detectedResults[index],
            originalImageSize: viewmodel.analyzedImages[index].size,
            visibleTypes: Array(visibleAcneTypes)
        )
        
        return filteredImage
    }
    
    func saveData() {
        let imagesBase64 = images.compactMap { $0.base64 }
        let analyzedImagesBase64 = viewmodel.analyzedImages.compactMap { $0.base64 }
        
        let result = Result(
            images: imagesBase64,
            selectedCardIndex: selectedCardIndex,
            analyzedImages: analyzedImagesBase64,
            isLoading: viewmodel.isLoading,
            acneCounts: viewmodel.acneCounts,
            geaScale: viewmodel.geaScale,
            currentDate: currentDate
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
