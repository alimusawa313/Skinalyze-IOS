import SwiftUI
import SkinalyzeKit

/// System search tab: products by name, brand or ingredient. Entry point for Product Check.
struct SearchView: View {
    @State private var query = ""
    @State private var showsLabelScanner = false

    private var results: [CatalogProduct] {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? [] : ProductCatalog.shared.search(query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    EmptyStateView(title: String(localized: "Is it good for you?"),
                                   message: String(localized: "Search a product or an ingredient — or scan a label — to see how it fits your skin.")) {
                        Button("Scan a label") { showsLabelScanner = true }
                            .buttonStyle(.dsSecondary)
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { product in
                        NavigationLink(value: product) {
                            HStack(spacing: Spacing.sm) {
                                ProductThumbnail(product: product)
                                VStack(alignment: .leading) {
                                    Text(product.name).font(.ds.callout)
                                    Text(product.brand).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .dsCanvas()
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Product, brand or ingredient")
            .navigationDestination(for: CatalogProduct.self) { ProductDetailView(product: $0) }
            .sheet(isPresented: $showsLabelScanner) { LabelScannerView() }
        }
    }
}
