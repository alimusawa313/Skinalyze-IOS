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


//var severityLevel: SkinSeverity{
//    switch acneLevelScale {
//    case 0:
//        return SkinSeverity(name: "Healthy", description: "The skin is clear with no signs of acne or other skin issues. It is healthy and free from inflammation or irritation.")
//    case 1:
//        return SkinSeverity(name: "Mild", description: "A few are present. Acne is infrequent and generally does not cause significant discomfort or affect daily activities.")
//    case 2:
//        return SkinSeverity(name: "Moderate", description: "Several papules or pustules are present. Acne is more frequent and often involves some degree of inflammation.")
//    case 3:
//        return SkinSeverity(name: "Severe", description: "Characterized by numerous papules, pustules, or nodules (large, inflamed bumps). Severe acne can lead to scarring and significantly affect daily life.")
//    default:
//        return SkinSeverity(name: "", description: "")
//    }
//}
