//
//  ProductSearchSheet.swift
//  Skinalyze
//
//  Created by Heical Chandra on 13/10/24.
//

import SwiftUI

struct ProductSearchView: View {
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    let categoryFilter: String
    let products: [SkincareProduct]
    
    var filteredProducts: [SkincareProduct] {
        if searchText.isEmpty {
            return products.filter {
                ($0.category?.lowercased() ?? "") == categoryFilter.lowercased()
            }
        } else {
            return products.filter { product in
                product.brand_name.lowercased().contains(searchText.lowercased()) &&
                (product.category?.lowercased() ?? "") == categoryFilter.lowercased()
            }
        }
    }
    
    @AppStorage("cleanserUsedID") private var cleanserUsedID: Int = 0
    @AppStorage("tonerUsedID") private var tonerUsedID: Int = 0
    @AppStorage("moisturizerUsedID") private var moisturizerUsedID: Int = 0
    @AppStorage("sunscreenUsedID") private var sunscreenUsedID: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Pick Your Product")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal, 15)
                SearchBar(text: $searchText)
                
                List(filteredProducts) { product in
                    HStack {
                        AsyncImage(url: URL(string: product.photo)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 75, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: {
                            Color.gray
                                .frame(width: 75, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        VStack(alignment: .leading) {
                            Text(product.name)
                                .font(.system(size: 18))
                                .fontWeight(.semibold)
                            HStack {
                                Text(product.brand_name)
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                                    
                                Spacer()
                                Text(product.category ?? "")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color("btnClr"))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color("splashScreen"))
                    .onTapGesture {
                        switch categoryFilter {
                        case "Cleanser":
                            cleanserUsedID = product.product_id
                        case "Toner":
                            tonerUsedID = product.product_id
                        case "Moisturizer":
                            moisturizerUsedID = product.product_id
                        case "Sunscreen":
                            sunscreenUsedID = product.product_id
                        default:
                            break
                        }
                        isPresented.toggle()
                    }
                    .listRowInsets(EdgeInsets())
//                    .background(Color("splashScreen"))
                    .padding()
                }
//                .background(Color("splashScreen"))
                .listStyle(PlainListStyle())
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
            }
            .padding(.top, 20)
            .background(Color("splashScreen"))
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        TextField("Search your product", text: $text) .padding(15)
            .background(Color("chatBg"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1)).foregroundStyle(.gray)
            )
            .overlay(
                HStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .padding(.trailing, 10)
                        .font(.system(size: 20))
                        .fontWeight(.semibold)
                }
            )
            .padding(.horizontal)
    }
}

struct ProductSearchView_Previews: PreviewProvider {
    @State static var isPresented = true
    @State static var previewProducts = SkincareProductViewModel().products
    
    static var previews: some View {
        NavigationView {
            ProductSearchView(isPresented: $isPresented,
                              categoryFilter: "Cleanser",
                              products: previewProducts)
        }
    }
}
