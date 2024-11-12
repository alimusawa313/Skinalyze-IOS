//
//  NewDetailViewTest.swift
//  Skinalyze
//
//  Created by Ali Haidar on 11/8/24.
//
import SwiftUI
import Vision
import CoreML
import SwiftData

struct NewDetailViewTest: View {
    
    @EnvironmentObject var router: Router
    @ObservedObject var viewmodel: ResultViewModel = ResultViewModel()
    @State private var currentDate = Date()
    
    @State private var selectedView = 0
    @State private var currentIndex = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State var selectedCardIndex = 0
    @State private var isShowingBoundingBoxes = false
    //    @State private var visibleAcneTypes: Set<String> = Set(["blackheads", "dark spot", "nodules", "papules", "pustules", "whiteheads"])
    
    @State private var visibleAcneTypes: Set<String> = []
    
    @Namespace private var namespace
    
    var selectedLogs: Result // The selected log containing the images
    var images: [UIImage] { // Extract images from selectedLogs
        return [
            selectedLogs.image1?.toImage(),
            selectedLogs.image2?.toImage(),
            selectedLogs.image3?.toImage()
        ].compactMap { $0 } // Ensure we only get non-nil images
    }
    
    private var acneTypesWithCounts: [Acne] {
        viewmodel.acneTypes.map { acne in
            var updatedAcne = acne
            updatedAcne.count = viewmodel.acneCounts[acne.countKey.lowercased(), default: 0]
            return updatedAcne
        }
    }
    
    var body: some View {
        ZStack{
            
            Color("splashScreen").ignoresSafeArea()
        ScrollView {
            VStack {
                // Display the current date
                HStack(alignment: .center) {
                    Text("\(selectedLogs.currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                }
                .font(.subheadline)
                .bold()
                
                // Show loading indicator or analyze results
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
                        analyzeImages() // Analyze images when the view appears
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: .infinity, height: UIScreen.main.bounds.height / 2)
                        Text("No images available").foregroundStyle(.white)
                    }
                }
                
                // Indicator for the current image in the TabView
                HStack {
                    ForEach(0..<images.count, id: \.self) { index in
                        Circle()
                            .frame(width: 8)
                            .foregroundColor(index == currentIndex ? .primary : .secondary)
                    }
                }
                .padding(5)
                .background(Capsule().foregroundStyle(.tertiary))
                
                // Severity // Level section
                HStack {
                    Text("Severity Level")
                        .font(.title3)
                        .bold()
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
                
                let severityLevel = AcneSeverityLevel(rawValue: selectedLogs.geaScale)!
                Text(severityDescriptions[severityLevel.rawValue]!)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
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
                            .padding(5).onAppear{
                                visibleAcneTypes = [acneType]
                            }
                        }
                    }
                    .padding(.bottom)
                }
                
                if viewmodel.geaScale > 0 {
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
        .onAppear{
            setInitialVisibleAcneType()
        }
    }
        
    }
    
    private func setInitialVisibleAcneType() {
        let availableTypes = viewmodel.acneCounts.keys.sorted().filter { viewmodel.acneCounts[$0] ?? 0 > 0 }
        
        // If there are available types, select the first one
        if !availableTypes.isEmpty {
            visibleAcneTypes = [availableTypes.first!]
        }
    }
    
    func filteredBoundingBoxImage(at index: Int) -> UIImage {
        guard index < viewmodel.boundingBoxImages.count else {
            return UIImage()
        }
        
        // If visibleAcneTypes is empty, find the first available acne type
        let visibleTypes: [String]
        if visibleAcneTypes.isEmpty {
            let availableTypes = viewmodel.acneCounts.keys.sorted().filter { viewmodel.acneCounts[$0] ?? 0 > 0 }
            visibleTypes = availableTypes.isEmpty ? [] : [availableTypes.first!]
        } else {
            visibleTypes = Array(visibleAcneTypes)
        }
        
        // Pass the visible types to the bounding box drawing method
        let filteredImage = viewmodel.drawBoundingBoxes(
            on: viewmodel.analyzedImages[index],
            results: viewmodel.detectedResults[index],
            originalImageSize: viewmodel.analyzedImages[index].size,
            visibleTypes: visibleTypes
        )
        
        return filteredImage
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

//#Preview {
//    NewDetailViewTest(selectedLogs: Result()) // Provide a mock or real Result object
//}
