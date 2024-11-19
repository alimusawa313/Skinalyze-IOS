//
//  ResultModel.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/14/24.
//

//import Foundation
//import SwiftData

//@Model
//class Result {
//    var id: UUID = UUID()
//    var timestamp: Date = Date.now
//    var image1: String?
//    var image2: String?
//    var image3: String?
//    var selectedCardIndex: Int
//    var analyzedImages1: String?
//    var analyzedImages2: String?
//    var analyzedImages3: String?
//    var isLoading: Bool
//    var acneCounts: [String: Int]
//    var geaScale: Int
//    var currentDate: Date
//    
//    init(images: [String], selectedCardIndex: Int, analyzedImages: [String], isLoading: Bool, acneCounts: [String: Int], geaScale: Int, currentDate: Date) {
//            self.selectedCardIndex = selectedCardIndex
//            self.isLoading = isLoading
//            self.acneCounts = acneCounts
//            self.geaScale = geaScale
//            self.currentDate = currentDate
//            
//            // Assign images
//            if images.count > 0 { image1 = images[0] }
//            if images.count > 1 { image2 = images[1] }
//            if images.count > 2 { image3 = images[2] }
//            
//            // Assign analyzed images
//            if analyzedImages.count > 0 { analyzedImages1 = analyzedImages[0] }
//            if analyzedImages.count > 1 { analyzedImages2 = analyzedImages[1] }
//            if analyzedImages.count > 2 { analyzedImages3 = analyzedImages[2] }
//        }
//}

import Foundation
import SwiftData

@Model
class Result {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var image1: String? = nil
    var image2: String? = nil
    var image3: String? = nil
    var selectedCardIndex: Int = 0
    var analyzedImages1: String? = nil
    var analyzedImages2: String? = nil
    var analyzedImages3: String? = nil
    var isLoading: Bool = false
    var acneCounts: [String: Int] = [:]
    var geaScale: Int = 0
    var currentDate: Date = Date()
    
    
    // New property to store bounding box images
    var boundingBoxImages: [String] = []
    
    // For saved products
    var cleanserUsedID: Int = 0
    var tonerUsedID: Int = 0
    var moisturizerUsedID: Int = 0
    var sunscreenUsedID: Int = 0
    
    init(images: [String] = [], selectedCardIndex: Int = 0, analyzedImages: [String] = [], isLoading: Bool = false, acneCounts: [String: Int] = [:], geaScale: Int = 0, currentDate: Date = Date(), boundingBoxImages: [String] = [], cleanserUsedID: Int = 0, tonerUsedID: Int = 0, moisturizerUsedID: Int = 0, sunscreenUsedID: Int = 0) {
        self.selectedCardIndex = selectedCardIndex
        self.isLoading = isLoading
        self.acneCounts = acneCounts
        self.geaScale = geaScale
        self.currentDate = currentDate
        
        // Assign images
        if images.count > 0 { image1 = images[0] }
        if images.count > 1 { image2 = images[1] }
        if images.count > 2 { image3 = images[2] }
        
        // Assign analyzed images
        if analyzedImages.count > 0 { analyzedImages1 = analyzedImages[0] }
        if analyzedImages.count > 1 { analyzedImages2 = analyzedImages[1] }
        if analyzedImages.count > 2 { analyzedImages3 = analyzedImages[2] }
        
        // Assign bounding box images
        self.boundingBoxImages = boundingBoxImages
        
        self.cleanserUsedID = cleanserUsedID
        self.tonerUsedID = tonerUsedID
        self.moisturizerUsedID = moisturizerUsedID
        self.sunscreenUsedID = sunscreenUsedID
    }
}
