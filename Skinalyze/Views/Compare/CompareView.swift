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
                    Text("Front").tag(0)
                    Text("Left").tag(1)
                    Text("Right").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical)
                
                HStack{
                    VStack{
                        Text("\(selectedLogs[1].currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                        
                        VStack(spacing: 5) {
                            ForEach(selectedLogs[1].acneCounts.keys.sorted().filter { selectedLogs[1].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "74574F").opacity(0.8))
                                    .overlay(
                                        Text("\(key.capitalized) (\(selectedLogs[1].acneCounts[key] ?? 0))")
                                            .bold()
                                            .font(.footnote)
                                            .foregroundColor(.white)
                                    )
                                    .frame(width: 120, height: 40)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                    }.frame(maxWidth: .infinity)
                    Spacer()
                    VStack{
                        Text("\(selectedLogs[0].currentDate, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                        
                        VStack(spacing: 5) {
                            ForEach(selectedLogs[0].acneCounts.keys.sorted().filter { selectedLogs[0].acneCounts[$0] ?? 0 > 0 }, id: \.self) { key in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "74574F").opacity(0.8))
                                    .overlay(
                                        Text("\(key.capitalized) (\(selectedLogs[0].acneCounts[key] ?? 0))")
                                            .bold()
                                            .font(.footnote)
                                            .foregroundColor(.white)
                                    )
                                    .frame(width: 120, height: 40)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding()
        }
        
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
                    .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 1.8)
                    .cornerRadius(10)
                
                Image(uiImage: secondImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width - 25, height: UIScreen.main.bounds.height / 1.8)
                    .cornerRadius(10)
                    .reverseMask {
                        HStack {
                            Spacer()
                            Rectangle()
                                .frame(width: max(UIScreen.main.bounds.width / 2 - xOffset - 12.5, 0), height: UIScreen.main.bounds.height / 1.8)
                            
                        }
                    }
                
                LineDivider(xOffset: $xOffset)
            }
        )
    }
}


//#Preview {
//    CompareView()
//}

////
struct LineDivider: View {
    @Binding var xOffset: CGFloat
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.white)
                .frame(width: 5, height: UIScreen.main.bounds.height / 1.8)
            Circle()
                .foregroundStyle(.white)
                .frame(width: 50)
        }
        .offset(x: xOffset)
        .gesture(DragGesture().onChanged { value in
            
            xOffset = min(max(value.translation.width, -UIScreen.main.bounds.width / 2 + 12.5), UIScreen.main.bounds.width / 2 - 12.5)
            
        })
    }
}

//struct LineDivider: View {
//    @Binding var xOffset: CGFloat
//    @State private var dragOffset: CGFloat = 0
//    
//    var body: some View {
//        ZStack {
//            Rectangle()
//                .foregroundStyle(.white)
//                .frame(width: 5, height: UIScreen.main.bounds.height / 1.8)
//            Circle()
//                .foregroundStyle(.white)
//                .frame(width: 50)
//        }
//        .offset(x: xOffset + dragOffset)
//        .gesture(
//            DragGesture()
//                .onChanged { value in
//                    let newOffset = xOffset + value.translation.width
//                    dragOffset = min(max(newOffset, -UIScreen.main.bounds.width / 2 + 12.5), UIScreen.main.bounds.width / 2 - 12.5) - xOffset
//                    
//                }
//                .onEnded { _ in
//                    xOffset += dragOffset
//                    dragOffset = 0
//                }
//        )
//    }
//}

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
