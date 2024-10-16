//
//  ContentCell.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/15/24.
//

import SwiftUI

struct ContentCell: View {
    let acne: Acne
    let isExpanded: Bool
    
    var body: some View {
        HStack{
            VStack(alignment: .leading){
                HStack{
                    Text(acne.name)
                        .font(Font.custom("Quattrocento Sans", size: 15))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .resizable()
                        .frame(width: 15, height: 8)
                        .scaledToFit()
                }
                if isExpanded{
                    VStack(alignment: .leading){
                        Text(acne.description)
                            .font(Font.custom("Quattrocento Sans", size: 12))
                            .foregroundColor(Color(red: 0.51, green: 0.5, blue: 0.5))
                    }
                    .padding(.top, 8)
                }
            }
            Spacer()
        }.contentShape(Rectangle())
    }
}

struct ScrollCell: ViewModifier{
    func body(content: Content) -> some View {
        Group{
            content
            Divider()
        }
    }
}
