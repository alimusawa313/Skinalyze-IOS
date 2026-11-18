//
//  NewCompareView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 11/11/24.
//

import SwiftUI
import SkinalyzeKit

struct NewCompareView: View {
    @ObservedObject var viewmodel: ResultViewModel = ResultViewModel()
    @State private var xOffset: CGFloat = 0
    var selectedLogs: [ScanSession]
    @State private var selectedSide = 0
    @EnvironmentObject var router: Router
    
    @State private var visibleAcneTypes: Set<String> = Set(["blackheads", "dark spot", "nodules", "papules", "pustules", "whiteheads"])
    
    
    var body: some View {
        ZStack{
            
            Color("splashScreen").ignoresSafeArea()
            ScrollView{
                VStack {
                    ZStack {
                        if selectedLogs.count == 2 {
                            displayImages(for: selectedSide)
                        }
                    }
                    
                    Picker("", selection: $selectedSide) {
                        Text("Left").tag(1)
                        Text("Front").tag(0)
                        Text("Right").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical)
                    
                    HStack{
                        VStack{
                            Text("\(selectedLogs[1].currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                            
                            HStack {
                                Text("Severity Level")
                                    .font(.footnote)
                                    .bold()
                                    .foregroundColor(Color("textPrimary"))
                                Spacer()
                                let severityLevel = AcneSeverityLevel(rawValue: selectedLogs[1].geaScale)!
                                Text("\(severityLevel)")
                                    .font(.footnote)
                                    .foregroundStyle(Color("textReverse"))
                                    .padding(EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7))
                                    .background(Capsule().foregroundStyle(Color("brownSecondary")))
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color("rowItemBg")))
                            
                            if !selectedLogs[1].acneCounts.filter ({ $0.value > 0 }).isEmpty {
                                VStack(alignment:.leading, spacing: 5) {
                                    Text("Skin Concern")
                                        .font(.footnote)
                                        .bold()
                                        .foregroundColor(Color("textPrimary"))
                                    ForEach(selectedLogs[1].acneCounts.keys.sorted().filter { selectedLogs[1].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                        HStack{
                                            Text("\(key.capitalized)")
                                                .font(.footnote)
                                                .foregroundColor(Color("textPrimary"))
                                            
                                            Spacer()
                                            
                                            Text("\(selectedLogs[1].acneCounts[key] ?? 0)")
                                                .frame(width: 40, height: 35)
                                                .foregroundStyle(Color("textReverse"))
                                                .background(Circle().foregroundStyle(Color("brownSecondary")))
                                            
                                        }
                                        
                                        Divider()
                                            .overlay(Color("textPrimary"))
                                    }
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color("rowItemBg")))
                            }
                            
                            Spacer()
                            
                        }.frame(maxWidth: .infinity)
                        
                        //                    Divider()
                        
                        
                        VStack{
                            Text("\(selectedLogs[0].currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                            
                            HStack {
                                Text("Severity Level")
                                    .font(.footnote)
                                    .bold()
                                    .foregroundColor(Color("textPrimary"))
                                Spacer()
                                let severityLevel = AcneSeverityLevel(rawValue: selectedLogs[0].geaScale)!
                                Text("\(severityLevel)")
                                    .font(.footnote)
                                    .foregroundStyle(Color("textReverse"))
                                    .padding(EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7))
                                    .background(Capsule().foregroundStyle(Color("brownSecondary")))
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color("rowItemBg")))
                            
                            if !selectedLogs[0].acneCounts.filter ({ $0.value > 0 }).isEmpty {
                                VStack(alignment:.leading, spacing: 5) {
                                    Text("Skin Concern")
                                        .font(.footnote)
                                        .bold()
                                        .foregroundColor(Color("textPrimary"))
                                    ForEach(selectedLogs[0].acneCounts.keys.sorted().filter { selectedLogs[0].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                        HStack{
                                            Text("\(key.capitalized)")
                                                .font(.footnote)
                                                .foregroundColor(Color("textPrimary"))
                                            
                                            Spacer()
                                            
                                            Text("\(selectedLogs[0].acneCounts[key] ?? 0)")
                                                .frame(width: 40, height: 35)
                                                .foregroundStyle(Color("textReverse"))
                                                .background(Circle().foregroundStyle(Color("brownSecondary")))
                                            
                                        }
                                        
                                        Divider()
                                            .overlay(Color("textPrimary"))
                                    }
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color("rowItemBg")))
                            }
                            
                            Spacer()
                            
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Comparison Result")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                Button("Done") {
                    router.navigateBack()
                }
            }
        }
    }

    private func displayImages(for side: Int) -> some View {
        // Saved scans are shown as saved — never re-analyzed. Missing images show nothing instead of crashing.
        guard selectedLogs.count == 2,
              let firstImage = selectedLogs[0].uiImage(at: side),
              let secondImage = selectedLogs[1].uiImage(at: side) else {
            return AnyView(EmptyView())
        }
        
        
        let firstLogImageIndex = side
        let secondLogImageIndex = 3 + side
        return AnyView(
            ZStack {
                ZStack{
                    Image(uiImage: firstImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 2.2)
                        .cornerRadius(10)
                    Image(uiImage: filteredBoundingBoxImage(at: firstLogImageIndex))
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 2.2)
                        .cornerRadius(10)
                }
                
                ZStack{
                    Image(uiImage: secondImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 2.2)
                        .cornerRadius(10)
                    Image(uiImage: filteredBoundingBoxImage(at: secondLogImageIndex))
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 2.2)
                        .cornerRadius(10)
                }
                .reverseMask {
                    HStack {
                        Spacer()
                        Rectangle()
                            .frame(width: max(UIScreen.main.bounds.width / 2 - xOffset - 12.5, 0), height: UIScreen.main.bounds.height / 2.2)
                        
                    }
                }
                
                LineDivider(xOffset: $xOffset)
            }
        )
    }
    
    func filteredBoundingBoxImage(at index: Int) -> UIImage {
        // Determine the log index (0 or 1) based on the total number of analyzed images
        let imagesPerLog = 3 // Assuming 3 images per log (front, left, right)
        let logIndex = index / imagesPerLog
        let imageIndexInLog = index % imagesPerLog
        
        guard logIndex < selectedLogs.count else {
            return UIImage()
        }
        
        let selectedLog = selectedLogs[logIndex]
        guard let image = selectedLog.uiImage(at: imageIndexInLog),
              let angle = selectedLog.captureAngle(at: imageIndexInLog) else {
            return UIImage()
        }
        let visibleTypes = Set(visibleAcneTypes.compactMap(LesionType.init(modelLabel:)))
        return DetectionOverlayRenderer.overlay(
            size: image.size,
            detections: selectedLog.detections(for: angle, types: visibleTypes)
        )
    }
}

//#Preview {
//    NewCompareView()
//}
