//
//  AcneSeverityLevel.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/14/24.
//

import Foundation

enum AcneSeverityLevel: Int, CaseIterable {
    case healthy = 0
    case mild = 1
    case moderate = 2
    case severe = 3
    case verySevere = 4
    case extremelySevere = 5

    var description: String {
        switch self {
        case .mild:
            return "Mild"
        case .moderate:
            return "Moderate"
        case .severe:
            return "Severe"
        case .verySevere:
            return "Very Severe"
        case .extremelySevere:
            return "Extremely Severe"
        case .healthy:
            return "Healthy"
        }
    }
}

struct Acne: Identifiable, Hashable{
    var id = UUID()
    let name: String
    let description: String
    var isExpanded: Bool = false
    var count: Int = 0
    var countKey: String
}

