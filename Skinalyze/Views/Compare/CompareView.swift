//
//  CompareView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/15/24.
//

import SwiftUI


struct CompareView: View {
    @State private var xOffset: CGFloat = 0
    var selectedLogs: [Result]
    @State private var selectedSide = 0
    
    var body: some View {
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
                                .foregroundColor(Color(hex: "3F3F44"))
                            Spacer()
                            let severityLevel = AcneSeverityLevel(rawValue: selectedLogs[1].geaScale)!
                            Text("\(severityLevel)")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding(.vertical,2)
                                .padding(.horizontal,4)
                                .background(Capsule().foregroundStyle(Color(hex: "74574F")))
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "EEEBE7").opacity(0.6)))
                        
                        VStack(alignment:.leading, spacing: 5) {
                                Text("Skin Concern")
                                    .font(.footnote)
                                    .bold()
                                    .foregroundColor(Color(hex: "3F3F44"))
                            ForEach(selectedLogs[1].acneCounts.keys.sorted().filter { selectedLogs[1].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                HStack{
                                    Text("\(key.capitalized)")
                                        .font(.footnote)
                                        .foregroundColor(Color(hex: "3F3F44"))
                                    
                                    Spacer()
                                    
                                    Text("\(selectedLogs[1].acneCounts[key] ?? 0)")
                                        .frame(width: 40, height: 35)
                                        .foregroundStyle(.white)
                                        .background(Circle().foregroundStyle(Color(hex: "74574F")))
                                    
                                }
                                
                                Divider()
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "EEEBE7").opacity(0.6)))
                        
                        Spacer()
                        
                    }.frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    
                    VStack{
                        Text("\(selectedLogs[0].currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                        
                        HStack {
                            Text("Severity Level")
                                .font(.footnote)
                                .bold()
                                .foregroundColor(Color(hex: "3F3F44"))
                            Spacer()
                            let severityLevel = AcneSeverityLevel(rawValue: selectedLogs[0].geaScale)!
                            Text("\(severityLevel)")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding(.vertical,2)
                                .padding(.horizontal,4)
                                .background(Capsule().foregroundStyle(Color(hex: "74574F")))
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "EEEBE7").opacity(0.6)))
                        
                        VStack(alignment:.leading, spacing: 5) {
                                Text("Skin Concern")
                                    .font(.footnote)
                                    .bold()
                                    .foregroundColor(Color(hex: "3F3F44"))
                            ForEach(selectedLogs[0].acneCounts.keys.sorted().filter { selectedLogs[0].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                HStack{
                                    Text("\(key.capitalized)")
                                        .font(.footnote)
                                        .foregroundColor(Color(hex: "3F3F44"))
                                    
                                    Spacer()
                                    
                                    Text("\(selectedLogs[0].acneCounts[key] ?? 0)")
                                        .frame(width: 40, height: 35)
                                        .foregroundStyle(.white)
                                        .background(Circle().foregroundStyle(Color(hex: "74574F")))
                                    
                                }
                                
                                Divider()
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "EEEBE7").opacity(0.6)))
                        
                        Spacer()
                        
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Comparison Result")
    }
    
    private func displayImages(for side: Int) -> some View {
        let imageStrings: (String?, String?) = {
            switch side {
            case 0:
                return (selectedLogs[0].analyzedImages1, selectedLogs[1].analyzedImages1)
            case 1:
                return (selectedLogs[0].analyzedImages2, selectedLogs[1].analyzedImages2)
            case 2:
                return (selectedLogs[0].analyzedImages3, selectedLogs[1].analyzedImages3)
            default:
                return (nil, nil)
            }
        }()
        
        guard let firstImageString = imageStrings.0,
              let firstImage = firstImageString.toImage(),
              let secondImageString = imageStrings.1,
              let secondImage = secondImageString.toImage() else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            ZStack {
                Image(uiImage: firstImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 2.2)
                    .cornerRadius(10)
                
                Image(uiImage: secondImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 2.2)
                    .cornerRadius(10)
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
}


#Preview {
    CompareView(selectedLogs: [Result(images: ["imageTest", "imageTest", "imageTest"], selectedCardIndex: 0, analyzedImages: ["imageTest", "imageTest", "imageTest"], isLoading: false, acneCounts: ["Popules": 89, "Pustul": 10], geaScale: 2, currentDate: Date.now), Result(images: ["imageTest", "imageTest", "imageTest"], selectedCardIndex: 0, analyzedImages: ["imageTest", "imageTest", "imageTest"], isLoading: false, acneCounts: ["Popules": 5, "Pustul": 10], geaScale: 2, currentDate: Date.now)])
}





struct LineDivider: View {
    @Binding var xOffset: CGFloat
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.white)
                .frame(width: 5, height: UIScreen.main.bounds.height / 2.2)
            
            Image(systemName: "chevron.left.chevron.right").bold()
                .padding()
                .background(
                    Circle()
                        .foregroundStyle(.white)
                )
        }
        .offset(x: xOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newOffset = xOffset + value.translation.width - dragOffset
                    xOffset = min(max(newOffset, -UIScreen.main.bounds.width / 2 + 12.5), UIScreen.main.bounds.width / 2 - 12.5)
                    dragOffset = value.translation.width
                }
                .onEnded { _ in
                    dragOffset = 0
                }
        )
    }
}


extension View {
    @inlinable
    public func reverseMask<Mask: View>(
        alignment: Alignment = .center,
        @ViewBuilder _ mask: () -> Mask
    ) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}
