//
//  RowItemCell.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/15/24.
//

import SwiftUI

struct RowItemHolder: View {

    var title: String
    @Binding var ingredients: [Ingredient]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title3)
                .bold()
                .padding(.bottom)
            
            ForEach(ingredients.indices, id: \.self) { index in
                IngredientRow(ingredient: $ingredients[index])
                Divider()
                    .overlay(Color("textPrimary"))
            }
        }
        .padding()
        .background(Color("rowItemBg").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct IngredientRow: View {
    @Binding var ingredient: Ingredient
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(ingredient.title)
                    .font(.subheadline)
                    .bold()
                Spacer()
                Image(systemName: ingredient.isExpanded ? "chevron.up" : "chevron.down")
            }
            .contentShape(Rectangle())
            if ingredient.isExpanded {
                Text(ingredient.description)
                    .font(.subheadline)
                    .padding(.top, 5)
            }
            
        }
        .cornerRadius(10)
        .onTapGesture {
            withAnimation(.bouncy) {
                ingredient.isExpanded.toggle()
            }
        }
    }
}
