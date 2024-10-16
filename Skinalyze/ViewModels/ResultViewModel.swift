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


class ResultViewModel: ObservableObject{
    @Published var selectedCells: Set<Acne> = []
    //    @Published var classifier = ImageClassifier()
    @Published var isAnimating: Bool = false
    @Published var isAcne: String = ""
    @Published var isBlackHead: String = ""
    
    //    private let skinUseCase: SkinUseCase = DefaultSkinUseCase()
    //    private let logUseCase: LogUseCase = DefaultLogUseCase()
    
    var currentDate: String = ""
    var skinType: String = ""
    let formatter = DateFormatter()
    var image: UIImage?
    private var cancellables = Set<AnyCancellable>()
    
    
    init(){
        //        skinUseCase.fetchLatestSkin { skin in
        //            if let skin = skin{
        //                self.skinType = skin.skinType
        //            }else{
        //                self.skinType = "Oily"
        //            }
        //        }
        //        formatter.dateFormat = "dd MMMM yyyy"
        //        currentDate = formatter.string(from: Date.now)
        //
        //        // Subscribe to changes in the classifier
        //        classifier.$acnePrediction
        //            .sink { [weak self] newValue in
        //                // Update isAcne dengan value langsung dari newValue (acnePrediction)
        //                self?.isAcne = newValue
        //                self?.objectWillChange.send()
        //            }
        //            .store(in: &cancellables)
        //
        //        classifier.$comedoPrediction
        //            .sink { [weak self] newValue in
        //                // Update isBlackHead dengan value langsung dari newValue (comedoPrediction)
        //                self?.isBlackHead = newValue
        //                self?.objectWillChange.send()
        //            }
        //            .store(in: &cancellables)
        //
        //        classifier.$acneLevelPrediction
        //            .sink { [weak self] newValue in
        //                self?.objectWillChange.send()
        //            }
        //            .store(in: &cancellables)
        
        //        classifier.$comedoPrediction
        //            .sink { [weak self] newValue in
        //                self?.objectWillChange.send()
        //            }
        //            .store(in: &cancellables)
    }
    
    //    var acneLevelScale: Int{
    //        let components = classifier.acneLevelPrediction.components(separatedBy: CharacterSet.decimalDigits.inverted)
    //        let numberString = components.joined()
    //        return Int(numberString) ?? 0
    //    }
    
    //    var severityLevel: SkinSeverity{
    //        switch acneLevelScale {
    //        case 0:
    //            return SkinSeverity(name: "Healthy", description: "The skin is clear with no signs of acne or other skin issues. It is healthy and free from inflammation or irritation.")
    //        case 1:
    //            return SkinSeverity(name: "Mild", description: "A few are present. Acne is infrequent and generally does not cause significant discomfort or affect daily activities.")
    //        case 2:
    //            return SkinSeverity(name: "Moderate", description: "Several papules or pustules are present. Acne is more frequent and often involves some degree of inflammation.")
    //        case 3:
    //            return SkinSeverity(name: "Severe", description: "Characterized by numerous papules, pustules, or nodules (large, inflamed bumps). Severe acne can lead to scarring and significantly affect daily life.")
    //        default:
    //            return SkinSeverity(name: "", description: "")
    //        }
    //    }
    
    //    var recommendedIngredients:[Ingredient]{
    //        if(skinType == "Oily" && classifier.acnePrediction == "Acne" && classifier.comedoPrediction == "Clear"){
    //            return acneOilyRec
    //        }else if(skinType == "Dry" && classifier.acnePrediction == "Acne" && classifier.comedoPrediction == "Clear"){
    //            return acneDryRec
    //        }else if(skinType == "Oily" && classifier.acnePrediction == "Clear" && classifier.comedoPrediction == "Comedo"){
    //            return blackheadOilyRec
    //        }else if(skinType == "Dry" && classifier.acnePrediction == "Clear" && classifier.comedoPrediction == "Comedo"){
    //            return blackheadDryRec
    //        }else if(skinType == "Oily" && classifier.acnePrediction == "Acne" && classifier.comedoPrediction == "Comedo"){
    //            return acneBlackheadOilyRec
    //        }else if(skinType == "Dry" && classifier.acnePrediction == "Acne" && classifier.comedoPrediction == "Comedo"){
    //            return acneBlackheadDryRec
    //        }else {
    //            return []
    //        }
    //    }
    //    var avoidedIngredients:[Ingredient]{
    //        if(skinType == "Oily"){
    //            return avoidOily
    //        }else{
    //            return avoidDry
    //        }
    //    }
    
    //    var facialCareRecommendation: [Habit]{
    //        if(skinType == "Oily"){
    //            return oilyHabits
    //        }else{
    //            return dryHabits
    //        }
    //    }
    
    
    @Published var acneTypes: [Acne] = [
        Acne(name: "Blackheads", description: "Your scan detected moderate acne, including the presence of blackheads. Blackheads are tiny open bumps filled with oil and dead skin, giving them a dark appearance.", countKey: "blackheads"),
        Acne(name: "Papules", description: "Your scan detected the presence of papules. Papules are small, solid bumps caused by oil, bacteria, and hormones. Unlike other acne, they don't have a pus-filled tip, but they can still feel irritated.", countKey: "papules"),
        Acne(name: "Pustules", description: "Your scan detected the presence of pustules. Pustules are small white bumps filled with fluid or pus, often surrounded by redness. These bumps may get bigger, but with the right care, you can manage them effectively.", countKey: "pustules"),
        Acne(name: "Whiteheads", description: "Your scan detected the presence of whiteheads. Whiteheads are closed bumps formed when oil and dead skin clog pores. While they're a common form of acne, they can be treated to prevent future breakouts.", countKey: "whiteheads"),
        Acne(name: "Nodules", description: "Your scan detected the presence of nodules. Nodules are firm, deep lumps that can be larger and more painful than other types of acne. They require targeted care for reduction and healing.", countKey: "nodules"),
        Acne(name: "Dark Spots", description: "Your scan detected the presence of dark spots. Dark spots, or hyperpigmentation, are caused by excess melanin production. They can appear due to sun exposure or aging, but with the right care, they can be lightened over time.", countKey: "dark spot")
    ]
    
    @Published var ingredients: [Ingredient] = [
        Ingredient(title: "Benzoyl Peroxide", description: "A beta hydroxy acid (BHA) that exfoliates the skin, uncloags pores, and reduces inflammation. It's particularly effective at treating and preventing papules and pustules."),
        Ingredient(title: "Salicylid Acid", description: "A beta hydroxy acid (BHA) that exfoliates the skin, uncloags pores, and reduces inflammation. It's particularly effective at treating and preventing papules and pustules."),
        Ingredient(title: "Retinoid", description: "A beta hydroxy acid (BHA) that exfoliates the skin, uncloags pores, and reduces inflammation. It's particularly effective at treating and preventing papules and pustules."),
        Ingredient(title: "Hyaluronic Acid", description: "A beta hydroxy acid (BHA) that exfoliates the skin, uncloags pores, and reduces inflammation. It's particularly effective at treating and preventing papules and pustules.")
    ]
    
    @Published var ingredientsNotRec: [Ingredient] = [
        Ingredient(title: "Alcohol", description: "A beta hydroxy acid (BHA) that exfoliates the skin, uncloags pores, and reduces inflammation. It's particularly effective at treating and preventing papules and pustules."),
        Ingredient(title: "Paraben", description: "A beta hydroxy acid (BHA) that exfoliates the skin, uncloags pores, and reduces inflammation. It's particularly effective at treating and preventing papules and pustules."),
        Ingredient(title: "Retinoid", description: "A beta hydroxy acid (BHA) that exfoliates the skin, uncloags pores, and reduces inflammation. It's particularly effective at treating and preventing papules and pustules."),
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
    
    //    func saveLog(){
    //        guard let imageBase64 = image?.base64 else{return}
    //
    //        let log = Log(imageURL: imageBase64, acnePrediction: classifier.acnePrediction, acneLevelPrediction: classifier.acneLevelPrediction, comedoPrediction: classifier.comedoPrediction, severityLevel: severityLevel.name, severityLevelDescription: severityLevel.description)
    //        logUseCase.save(log: log)
    //    }
    
    
    
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
