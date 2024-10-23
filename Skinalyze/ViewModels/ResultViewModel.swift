//
//  ResultViewModel.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/14/24.
//

import Foundation
import Combine
import UIKit
import Vision
import CoreML
import SwiftData
import SwiftUI


class ResultViewModel: ObservableObject{
    @Published var selectedCells: Set<Acne> = []
    //    @Published var classifier = ImageClassifier()
    @Published var isAnimating: Bool = false
    @Published var isAcne: String = ""
    @Published var isBlackHead: String = ""
    
    //    private let skinUseCase: SkinUseCase = DefaultSkinUseCase()
    //    private let logUseCase: LogUseCase = DefaultLogUseCase()
    
    var currentDate: String = ""
    //    var skinType: String = ""
    let formatter = DateFormatter()
    var image: UIImage?
    private var cancellables = Set<AnyCancellable>()
    
    
    init(){
        
        updateIngredients()
        
    }
    
    
    
    @Published var acneTypes: [Acne] = [
        Acne(name: "Blackheads", description: "Your scan detected moderate acne, including the presence of blackheads. Blackheads are tiny open bumps filled with oil and dead skin, giving them a dark appearance.", countKey: "blackheads"),
        Acne(name: "Papules", description: "Your scan detected the presence of papules. Papules are small, solid bumps caused by oil, bacteria, and hormones. Unlike other acne, they don't have a pus-filled tip, but they can still feel irritated.", countKey: "papules"),
        Acne(name: "Pustules", description: "Your scan detected the presence of pustules. Pustules are small white bumps filled with fluid or pus, often surrounded by redness. These bumps may get bigger, but with the right care, you can manage them effectively.", countKey: "pustules"),
        Acne(name: "Whiteheads", description: "Your scan detected the presence of whiteheads. Whiteheads are closed bumps formed when oil and dead skin clog pores. While they're a common form of acne, they can be treated to prevent future breakouts.", countKey: "whiteheads"),
        Acne(name: "Nodules", description: "Your scan detected the presence of nodules. Nodules are firm, deep lumps that can be larger and more painful than other types of acne. They require targeted care for reduction and healing.", countKey: "nodules"),
        Acne(name: "Dark Spots", description: "Your scan detected the presence of dark spots. Dark spots, or hyperpigmentation, are caused by excess melanin production. They can appear due to sun exposure or aging, but with the right care, they can be lightened over time.", countKey: "dark spot")
    ]
    
    
    @Published var expandedAcnes: [String] = []
    
    func isExpanded(acne: String) -> Bool {
        return expandedAcnes.contains(acne)
    }
    
    func expandCell(ingredient: String) {
        if let index = expandedAcnes.firstIndex(of: ingredient) {
            expandedAcnes.remove(at: index)
        } else {
            expandedAcnes.append(ingredient)
        }
    }
    
    func expandCell(ingredient: Acne){
        if selectedCells.contains(ingredient){
            selectedCells.remove(ingredient)
        }else{
            selectedCells.insert(ingredient)
        }
    }
    
    @AppStorage("skinType") private var skinType: String = ""
    @AppStorage("skinSensitivity") private var skinSensitivity: String = ""
    
    @Published var ingredients: [Ingredient] = []
    @Published var ingredientsNotRec: [Ingredient] = []
    
    func updateIngredients() {
        ingredients = getRecommendedIngredients()
        ingredientsNotRec = getIngredientsToAvoid()
    }
    
    private func getRecommendedIngredients() -> [Ingredient] {
        switch skinType.lowercased() {
        case "oily":
            return [
                Ingredient(title: "Salicylic Acid", description: "A beta-hydroxy acid that helps unclog pores and reduce excess oil."),
                Ingredient(title: "Niacinamide", description: "Helps regulate oil production and minimize pores."),
                Ingredient(title: "Tea Tree Oil", description: "Has antibacterial properties and can help control oil production."),
                Ingredient(title: "Hyaluronic Acid", description: "Provides lightweight hydration without adding oil.")
            ]
        case "dry":
            return [
                Ingredient(title: "Hyaluronic Acid", description: "Attracts and retains moisture in the skin."),
                Ingredient(title: "Glycerin", description: "A humectant that helps skin retain moisture."),
                Ingredient(title: "Ceramides", description: "Help strengthen the skin barrier and lock in moisture."),
                Ingredient(title: "Squalane", description: "A lightweight oil that moisturizes without clogging pores.")
            ]
        case "combination":
            return [
                Ingredient(title: "Niacinamide", description: "Balances oil production and improves skin texture."),
                Ingredient(title: "Hyaluronic Acid", description: "Provides hydration without being too heavy."),
                Ingredient(title: "Alpha Hydroxy Acids (AHAs)", description: "Gently exfoliate and balance both dry and oily areas."),
                Ingredient(title: "Green Tea Extract", description: "Antioxidant that soothes and balances the skin.")
            ]
        default: // For normal skin or unspecified
            return [
                Ingredient(title: "Vitamin C", description: "Antioxidant that brightens skin and protects from environmental damage."),
                Ingredient(title: "Peptides", description: "Help stimulate collagen production and improve skin firmness."),
                Ingredient(title: "Hyaluronic Acid", description: "Hydrates and plumps the skin."),
                Ingredient(title: "Retinol", description: "Promotes cell turnover and helps with overall skin health.")
            ]
        }
    }
    
    private func getIngredientsToAvoid() -> [Ingredient] {
        var baseIngredientsToAvoid = [
            Ingredient(title: "Artificial Fragrances", description: "Can irritate the skin and cause allergic reactions."),
            Ingredient(title: "Parabens", description: "Preservatives that may disrupt hormones and irritate skin.")
        ]
        
        switch skinType.lowercased() {
        case "oily":
            baseIngredientsToAvoid += [
                Ingredient(title: "Coconut Oil", description: "Can clog pores and exacerbate oily skin."),
                Ingredient(title: "Alcohol", description: "Can strip the skin of natural oils, leading to more oil production.")
            ]
        case "dry":
            baseIngredientsToAvoid += [
                Ingredient(title: "Alcohol", description: "Can further dry out and irritate dry skin."),
                Ingredient(title: "Sodium Lauryl Sulfate", description: "A harsh cleanser that can strip skin of natural oils.") ]
        case "combination":
            baseIngredientsToAvoid += [
                Ingredient(title: "Mineral Oil", description: "Can clog pores and cause irritation in oily areas."),
                Ingredient(title: "Sodium Lauryl Sulfate", description: "A harsh cleanser that can strip skin of natural oils.")]
        default: // For normal skin or unspecified
            break
        }
        
        return baseIngredientsToAvoid
    }
    
    @Published var analyzedImages: [UIImage] = []
    @Published var isLoading = false
    @Published var geaScale = 1
    @Published var acneCounts: [String: Int] = [
        "blackheads": 0,
        "dark spot": 0,
        "nodules": 0,
        "papules": 0,
        "pustules": 0,
        "whiteheads": 0
    ]
    
    func updateAcneCounts(with results: [VNRecognizedObjectObservation]) {
        for result in results {
            let label = result.labels.first?.identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
            //            print("Detected label: \(label)")  // Debugging output
            
            // Increment count for the detected label, ensuring case insensitivity
            if let _ = acneCounts[label] {
                acneCounts[label, default: 0] += 1
            }
        }
    }
    
    // GEA Scale calculation logic based on detected acne counts
    func calculateGEAScale() {
        let papulesCount = acneCounts["papules"] ?? 0
        let pustulesCount = acneCounts["pustules"] ?? 0
        let nodulesCount = acneCounts["nodules"] ?? 0
        let blackheadsCount = acneCounts["blackhead"] ?? 0
        let whiteheadsCount = acneCounts["whiteheads"] ?? 0
        
        if nodulesCount > 5 || pustulesCount > 10 {
            // Stage 4 (Very Severe Acne) or Stage 5 (Extremely Severe Acne)
            geaScale = nodulesCount > 10 || pustulesCount > 15 ? 5 : 4
        } else if pustulesCount > 5 || papulesCount > 10 {
            // Stage 3 (Severe Ac ne)
            geaScale = 3
        } else if papulesCount > 5 || blackheadsCount > 10 || whiteheadsCount > 10 {
            // Stage 2 (Moderate Acne)
            geaScale = 2
        } else if papulesCount == 0 && pustulesCount == 0 && nodulesCount == 0 && blackheadsCount == 0 && whiteheadsCount == 0 {
            geaScale = 0
        }
        else {
            // Stage 1 (Mild Acne)
            geaScale = 1
        }
    }
    
    func drawBoundingBoxes(on image: UIImage, results: [VNRecognizedObjectObservation], originalImageSize: CGSize) -> UIImage {
        let imageSize = originalImageSize
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
        
        // Draw the original image
        image.draw(in: CGRect(origin: .zero, size: imageSize))
        
        // Set up the context for drawing bounding boxes
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.setLineWidth(9.0)
        
        // Define color mapping for each label
        let labelColorMapping: [String: UIColor] = [
            "blackheads": UIColor.cyan,
            "dark spot": UIColor.blue,
            "nodules": UIColor.red,
            "papules": UIColor.orange,
            "pustules": UIColor.green,
            "whiteheads": UIColor.gray,
        ]
        
        for result in results {
            let boundingBox = result.boundingBox
            
            // Get the label and confidence
            let label = result.labels.first?.identifier ?? "Unknown"
            let confidence = result.labels.first?.confidence ?? 0.0
            
            // Select the color based on the label
            //            let color = labelColorMapping[label, default: UIColor.black]
            let color = labelColorMapping[label, default: UIColor.black]
            
            // Set the stroke color for the bounding box
            context.setStrokeColor(color.cgColor)
            
            // Convert the bounding box to the original image's coordinate system (flipping the y-axis)
            let rect = CGRect(
                x: boundingBox.minX * imageSize.width,
                y: (1 - boundingBox.minY - boundingBox.height) * imageSize.height,
                width: boundingBox.width * imageSize.width,
                height: boundingBox.height * imageSize.height
            )
            
            // Draw the bounding box
            context.stroke(rect)
            
            // Draw the label text with the same color
            let labelText = "\(label) (\(Int(confidence * 100))%)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30),
                .foregroundColor: color,
                .backgroundColor: UIColor.white
            ]
            
            // Determine where to draw the label
            let textSize = labelText.size(withAttributes: attributes)
            let labelRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y - textSize.height, // Position above the bounding box
                width: textSize.width,
                height: textSize.height
            )
            
            // Draw the label text in the image
            //            labelText.draw(in: labelRect, withAttributes: attributes)
        }
        
        // Get the new image with bounding boxes and labels
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    
    func resetAcneCounts() {
        acneCounts = [
            "blackheads": 0,
            "dark spot": 0,
            "nodules": 0,
            "papules": 0,
            "pustules": 0,
            "whiteheads": 0
        ]
    }
    
    func detectObjects(in image: UIImage, completion: @escaping () -> Void) {
        let inputSize = CGSize(width: 224, height: 224)
        
        guard let resizedImage = image.resized(to: inputSize),
              let ciImage = CIImage(image: resizedImage) else {
            print("Failed to resize image or convert UIImage to CIImage")
            completion()
            return
        }
        
        let config = MLModelConfiguration()
        guard let model = try? VNCoreMLModel(for: acneObj28200(configuration: config).model) else {
            print("Failed to load model")
            completion()
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("Error in CoreML request: \(error.localizedDescription)")
                completion()
                return
            }
            
            if let results = request.results as? [VNRecognizedObjectObservation] {
                DispatchQueue.main.async {
                    let analyzedImage = self.drawBoundingBoxes(on: image, results: results, originalImageSize: image.size)
                    self.analyzedImages.append(analyzedImage)
                    self.updateAcneCounts(with: results) // Update counts based on detected results
                    completion()
                }
            } else {
                completion()
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform image request: \(error.localizedDescription)")
            completion()
        }
    }
    
}
