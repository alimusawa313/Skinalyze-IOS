//
//  ProductUsedSaved.swift
//  Skinalyze
//
//  Created by Ali Haidar on 11/8/24.
//

import SwiftUI


struct ProductUsedSaved: View {
//    var isFromStartup: Bool
    
    @StateObject var viewModel = SkincareProductViewModel()
    @State private var showCleanserSheet = false
    @State private var showTonerSheet = false
    @State private var showMoisturizerSheet = false
    @State private var showSunscreenSheet = false
    @State private var moveToCamScanner = false
    
    var cleanserUsedID: Int = 0
    var tonerUsedID: Int = 0
    var moisturizerUsedID: Int = 0
    var sunscreenUsedID: Int = 0
    
    var body: some View {
        
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Cleanser")
                        .bold()
                    HStack{
                        if cleanserUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("12345")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("12345")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                        } else {
                            // Cari produk berdasarkan cleanserUsedID
                            if let cleanserProduct = viewModel.products.first(where: { $0.product_id == cleanserUsedID }) {
                                ZStack(alignment: .topTrailing) {
                                    VStack {
                                        AsyncImage(url: URL(string: cleanserProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 149, height: 131)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(cleanserProduct.name)
                                                .font(.headline)
                                                .foregroundColor(Color("textPrimary"))
                                                .lineLimit(2, reservesSpace: true)
                                            Text(cleanserProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    // Button "X" to delete the product
//                                    Button(action: {
//                                        cleanserUsedID = 0
//                                    }) {
//                                        Image(systemName: "xmark.circle.fill")
//                                            .foregroundColor(Color("brownTest"))
//                                            
//                                    }
                                }
                            }
                            else {
                                Text("Product not found")
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showCleanserSheet) {
                        ProductSearchView(isPresented: $showCleanserSheet, categoryFilter: "Cleanser", products: viewModel.products)
                    }
                }
                
                
                VStack(alignment:.leading){
                    Text("Toner")
                        .bold()
                    HStack{
                        if tonerUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("12345")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("12345")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                        } else {
                            // Cari produk berdasarkan cleanserUsedID
                            if let tonerProduct = viewModel.products.first(where: { $0.product_id == tonerUsedID }) {
                                ZStack(alignment:.topTrailing) {
                                    VStack {
                                        AsyncImage(url: URL(string: tonerProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading) {
                                            Text(tonerProduct.name)
                                                .font(.headline)
                                                .foregroundColor(Color("textPrimary"))
                                                .lineLimit(2, reservesSpace: true)
                                            //                                            .truncationMode(.tail)
                                            Text(tonerProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
//                                    Button(action: {
//                                        tonerUsedID = 0
//                                    }) {
//                                        Image(systemName: "xmark.circle.fill")
//                                            .foregroundColor(Color("brownTest"))
//                                            
//                                    }
                                }
                            } else {
                                Text("Product not found")
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showTonerSheet) {
                        ProductSearchView(isPresented: $showTonerSheet, categoryFilter: "Toner", products: viewModel.products)
                    }
                }
            }
            .padding()
            HStack(spacing: 20) {
                VStack(alignment:.leading){
                    Text("Moisturizer")
                        .bold()
                    HStack{
                        if moisturizerUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("1")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("1")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                            
                        } else {
                            if let moisturizerProduct = viewModel.products.first(where: { $0.product_id == moisturizerUsedID }) {
                                ZStack(alignment:.topTrailing){
                                    VStack {
                                        AsyncImage(url: URL(string: moisturizerProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                            //                                            .padding()
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            //                                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 7)
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading) {
                                            Text(moisturizerProduct.name)
                                                .font(.headline)
                                                .foregroundColor(Color("textPrimary"))
                                                .lineLimit(2, reservesSpace: true)
                                            Text(moisturizerProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
//                                    Button(action: {
//                                        moisturizerUsedID = 0
//                                    }) {
//                                        Image(systemName: "xmark.circle.fill")
//                                            .foregroundColor(Color("brownTest"))
//                                            
//                                    }
                                }
                            } else {
                                Text("Product not found") // Fallback jika ID tidak sesuai
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showMoisturizerSheet) {
                        ProductSearchView(isPresented: $showMoisturizerSheet, categoryFilter: "Moisturizer", products: viewModel.products)
                    }
                }
                VStack(alignment:.leading){
                    Text("Sunscreen")
                        .bold()
                    HStack{
                        if sunscreenUsedID == 0 {
                            VStack {
                                Image("AddProductBtn")
                                VStack(alignment: .leading) {
                                    Text("12345")
                                        .font(.headline)
                                        .foregroundColor(.black.opacity(0))
                                        .lineLimit(2, reservesSpace: true)
                                    Text("12345")
                                        .font(.subheadline)
                                        .foregroundColor(.black.opacity(0))
                                }
                            }
                        } else {
                            // Cari produk berdasarkan cleanserUsedID
                            if let sunscreenProduct = viewModel.products.first(where: { $0.product_id == sunscreenUsedID }) {
                                ZStack(alignment:.topTrailing){
                                    VStack {
                                        AsyncImage(url: URL(string: sunscreenProduct.photo)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 149, height: 131)
                                            //                                            .padding()
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            //                                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 7)
                                            
                                        } placeholder: {
                                            Color.gray
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading) {
                                            Text(sunscreenProduct.name)
                                                .font(.headline)
                                                .foregroundColor(Color("textPrimary"))
                                                .lineLimit(2, reservesSpace: true)
                                            Text(sunscreenProduct.brand_name)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
//                                    Button(action: {
//                                        sunscreenUsedID = 0
//                                    }) {
//                                        Image(systemName: "xmark.circle.fill")
//                                            .foregroundColor(Color("brownTest"))
//                                            
//                                    }
                                }
                            } else {
                                Text("Product not found") // Fallback jika ID tidak sesuai
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                    .sheet(isPresented: $showSunscreenSheet) {
                        ProductSearchView(isPresented: $showSunscreenSheet, categoryFilter: "Sunscreen", products: viewModel.products)
                    }
                }
            }
            .padding()
            Spacer()
        .padding(.top, 50 )
        .onAppear {
            viewModel.loadJSON()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
