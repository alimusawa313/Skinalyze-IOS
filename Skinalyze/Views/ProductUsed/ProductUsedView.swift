//
//  ProductUsedView.swift
//  Skinalyze
//
//  Created by Heical Chandra on 12/10/24.
//

import SwiftUI

struct ProductUsedView: View {
    var isFromStartup: Bool
    
    @EnvironmentObject var router: Router
    
    @StateObject var viewModel = SkincareProductViewModel()
    @State private var showCleanserSheet = false
    @State private var showTonerSheet = false
    @State private var showMoisturizerSheet = false
    @State private var showSunscreenSheet = false
    @State private var moveToCamScanner = false
    
    @AppStorage("cleanserUsedID") private var cleanserUsedID: Int = 0
    @AppStorage("tonerUsedID") private var tonerUsedID: Int = 0
    @AppStorage("moisturizerUsedID") private var moisturizerUsedID: Int = 0
    @AppStorage("sunscreenUsedID") private var sunscreenUsedID: Int = 0
    
    var body: some View {
        ZStack{
            Color("splashScreen").ignoresSafeArea()
            VStack {
                if isFromStartup{
                    Text("Add Your Skincare Products")
                        .foregroundColor(Color("textPrimary"))
                        .font(.title2)
                        .bold()
                        .padding(.bottom, 5)
                    Text("To log the skincare products you're using today. You can review your past products in the scan results.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color("textPrimary").opacity(0.7))
                        .font(.subheadline)
                        .padding(.horizontal, 24)
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Cleanser")
                            .bold()
                        Button(action: { showCleanserSheet.toggle() }) {
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
                                        Button(action: {
                                            cleanserUsedID = 0
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(Color("brownTest"))
                                                
                                        }
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
                        Button(action: { showTonerSheet.toggle() }) {
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
                                        Button(action: {
                                            tonerUsedID = 0
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(Color("brownTest"))
                                                
                                        }
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
                        Button(action: { showMoisturizerSheet.toggle() }) {
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
                                        Button(action: {
                                            moisturizerUsedID = 0
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(Color("brownTest"))
                                                
                                        }
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
                        Button(action: { showSunscreenSheet.toggle() }) {
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
                                        Button(action: {
                                            sunscreenUsedID = 0
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(Color("brownTest"))
                                                
                                        }
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
                
            }
            .navigationTitle("Saved Products")
            .navigationBarTitleDisplayMode(isFromStartup ? .inline : .large)
            .toolbar {
                if(isFromStartup){
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            moveToCamScanner.toggle()
                            router.navigate(to: .camScanView)
                        }
                        .foregroundColor(Color("brownTest"))
                    }
                }
            }
            .padding(.top, isFromStartup ? 50 : 20)
            .onAppear {
                viewModel.loadJSON()
            }
            .navigationTitle("Skinalyze")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isFromStartup ? true : false)
        }
    }
}

struct ProductListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView{
            ProductUsedView(isFromStartup: false)
        }
    }
}
