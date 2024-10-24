//
//  ProductViewModel.swift
//  Skinalyze
//
//  Created by Heical Chandra on 12/10/24.
//

import Foundation

class SkincareProductViewModel: ObservableObject {
    @Published var products: [SkincareProduct] = []
    
    func loadJSON() {
        if let url = Bundle.main.url(forResource: "SkincareProducts", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let loadedProducts = try decoder.decode([SkincareProduct].self, from: data)
                DispatchQueue.main.async {
                    self.products = loadedProducts
                    print("Loaded products: \(self.products)") // Pastikan ini menampilkan produk
                    print("Products Count: \(self.products.count)") // Hitung jumlah produk
                }
            } catch {
                print("Failed to load JSON: \(error)")
            }
        } else {
            print("JSON file not found")
        }
    }

}
