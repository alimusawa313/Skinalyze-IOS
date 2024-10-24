//
//  AcneRowItem.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/16/24.
//

import SwiftUI


struct AcneRowItem: View {
    var title: String
    var acne: [Acne]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title3)
                .bold()
                .padding(.bottom)
            
            ForEach(acne.filter { $0.count > 0 }, id: \.id) { acneItem in
                AcneRow(acne: acneItem)
            }
        }
        .padding()
        .background(Color(hex: "EEEBE7").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AcneRow: View {
    @State private var isExpanded: Bool = false
    let acne: Acne
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(acne.name)
                    .font(.subheadline)
                    .bold()
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            if isExpanded {
                Text(acne.description)
                    .font(.subheadline)
                    .padding(.top, 5)
            }
            Divider()
        }
        .cornerRadius(10)
        .onTapGesture {
            withAnimation(.bouncy) {
                isExpanded.toggle()
            }
        }
    }
}
