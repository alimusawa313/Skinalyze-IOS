//
//  IngridientModel.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/15/24.
//

import Foundation
struct Ingredient: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var isExpanded: Bool = false
}
