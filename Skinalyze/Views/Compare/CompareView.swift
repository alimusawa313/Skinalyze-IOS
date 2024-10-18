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
                        
                        VStack(spacing: 5) {
                            ForEach(selectedLogs[1].acneCounts.keys.sorted().filter { selectedLogs[1].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                HStack{
                                    Spacer()
                                    Text("\(key.capitalized)")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(selectedLogs[0].acneCounts[key] ?? 0)")
                                        .frame(width: 40, height: 35)
                                        .background(Color(hex: "D6C7C2"))
                                }
                                .background(Color(hex: "795B53"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer()
                        
                    }.frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    
                    VStack{
                        Text("\(selectedLogs[0].currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                        
                        VStack(spacing: 5) {
                            ForEach(selectedLogs[0].acneCounts.keys.sorted().filter { selectedLogs[0].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                HStack{
                                    Spacer()
                                    Text("\(key.capitalized)")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(selectedLogs[0].acneCounts[key] ?? 0)")
                                        .frame(width: 40, height: 35)
                                        .background(Color(hex: "D6C7C2"))
                                }
                                .background(Color(hex: "795B53"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
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
    CompareView(selectedLogs: [Result(images: ["imageTest", "imageTest", "imageTest"], selectedCardIndex: 0, analyzedImages: ["imageTest", "imageTest", "imageTest"], isLoading: false, acneCounts: ["Popules": 5, "Pustul": 10], geaScale: 2, currentDate: Date.now), Result(images: ["imageTest", "imageTest", "imageTest"], selectedCardIndex: 0, analyzedImages: ["imageTest", "imageTest", "imageTest"], isLoading: false, acneCounts: [:], geaScale: 2, currentDate: Date.now)])
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
