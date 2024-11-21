//
//  SkinCareRecommendationsSourceView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 11/21/24.
//

import SwiftUI

struct SkinCareRecommendationsSourceView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Oily Skin Recommendations")) {
                    Text("Salicylic Acid and Tea Tree Oil are well-known for their ability to help with oil control and acne prevention.")
                    Text("Niacinamide is commonly recommended for balancing oil production and reducing pore size.")
                    Text("Hyaluronic Acid is often used in oily skincare routines to hydrate without contributing to excess oil production.")
                    
                    Section(header: Text("Sources:").bold()) {
                        Link("American Academy of Dermatology (AAD)", destination: URL(string: "https://www.aad.org/public/diseases/acne/diy/adult-acne-treatment")!)
                    }
                }
                
                
                Section(header: Text("Dry Skin Recommendations")) {
                    Text("Hyaluronic Acid and Glycerin are famous humectants known for attracting moisture.")
                    Text("Ceramides and Squalane are known to restore and strengthen the skin barrier, which is critical for dry skin.")
                    
                    Section(header: Text("Sources:").bold()) {
                        Link("What to Know About Ceramides for Skin", destination: URL(string: "https://www.webmd.com/beauty/what-to-know-about-ceramides-for-skin")!)
                        Link("The Benefits of Glycerin for Your Skin", destination: URL(string: "https://www.kiehls.com/skincare-advice/glycerin-benefits-for-skin.html")!)
                    }
                }
                
                
                
                Section(header: Text("Combination Skin Recommendations")) {
                    Text("Niacinamide, Hyaluronic Acid, and Alpha Hydroxy Acids (AHAs) are often recommended for balancing and hydrating combination skin.")
                    Text("Green Tea Extract is popular for its antioxidant and anti-inflammatory properties, suitable for soothing skin.")
                    
                    
                    Section(header: Text("Sources:").bold()) {
                        Link("Katiyar S. K. (2011) - Green tea prevents non-melanoma skin cancer", destination: URL(string: "https://doi.org/10.1016/j.abb.2010.11.015")!)
                        Link("Everything You Need to Know About Using Alpha Hydroxy Acids (AHAs)", destination: URL(string: "https://www.healthline.com/health/beauty-skin-care/alpha-hydroxy-acid")!)
                    }
                }
                
                
                Section(header: Text("Normal Skin Recommendations")) {
                    Text("Vitamin C and Peptides are widely recommended for brightening and promoting collagen production in normal skin.")
                    Text("Retinol is known for its anti-aging properties and promoting skin health.")
                    
                    Section(header: Text("Sources:").bold()) {
                        Link("Retinoid or retinol? (American Academy of Dermatology)", destination: URL(string: "https://www.aad.org/public/everyday-care/skin-care-secrets/anti-aging/retinoid-retinol")!)
                        Link("WebMD: Benefits of Vitamin C for skin", destination: URL(string: "https://www.webmd.com/beauty/ss/slideshow-benefits-of-vitamin-c-for-skin")!)
                    }
                }
                
                
                Section(header: Text("Ingredients to Avoid")) {
                    Text("Parabens and Artificial Fragrances are commonly cited as irritants, especially for sensitive skin.")
                    Text("Coconut Oil, Alcohol, and Sodium Lauryl Sulfate are frequently recommended to be avoided for specific skin types, such as oily or dry skin, due to their potential to irritate or worsen the condition.")
                    
                    
                    Section(header: Text("Sources:").bold()) {
                        Link("The Upside and Downside of Using Coconut Oil in Skincare", destination: URL(string: "https://buckheaddermatology.com/the-upside-and-downside-of-using-coconut-oil-in-skincare/#:~:text=Coconut%20oil%20is%20comedogenic%2C%20which,oil%20as%20a%20hydrating%20product")!)
                        Link("Advances in Relationship Between Alcohol Consumption and Skin Diseases", destination: URL(string: "https://doi.org/10.2147/CCID.S443128")!)
                        Link("Sodium Lauryl Sulfate-induced barrier disruption and irritation", destination: URL(string: "https://doi.org/10.1111/j.1365-2133.2005.06531.x")!)
                    }
                }
                
                
            }
            .navigationTitle("Where we got the sources?")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(InsetGroupedListStyle())
        }
    }
}



#Preview {
    SkinCareRecommendationsSourceView()
}
