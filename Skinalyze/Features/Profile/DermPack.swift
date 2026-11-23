import SwiftData
import SwiftUI
import UIKit
import SkinalyzeKit

// P11 dermatologist visit pack (Pro): a few pages a doctor can read in a minute — the trend, each area's count,
// chosen photos, the products used and when, and the journal. Clearly labelled as not a medical document. The PDF is
// made on the phone and leaves only when the user shares it.

/// Everything the pages show, gathered once (photos decoded and shrunk off the main thread).
struct DermPackContent {
    struct Photo: Identifiable {
        let id: UUID
        let date: Date
        let image: UIImage
    }

    struct Product: Identifiable {
        let id: Int
        let name: String
        let brand: String
        let started: Date
        let stopped: Date?
    }

    let scans: [ScanSession]
    let photos: [Photo]
    let products: [Product]
    let journal: [(tag: JournalTag, days: Int)]
    let notes: [(date: Date, text: String)]

    var first: Date? { scans.first?.createdAt }
    var last: Date? { scans.last?.createdAt }

    static let photoCount = 6
    static let photoSide: CGFloat = 480
}

enum DermPackBuilder {
    /// Up to `photoCount` scans spread evenly from first to last, always including both ends.
    static func photoScans(_ scans: [ScanSession]) -> [ScanSession] {
        guard scans.count > DermPackContent.photoCount else { return scans }
        let step = Double(scans.count - 1) / Double(DermPackContent.photoCount - 1)
        return (0..<DermPackContent.photoCount).map { scans[Int((Double($0) * step).rounded())] }
    }

    @MainActor
    static func content(scans: [ScanSession], includePhotos: Bool, journal: JournalModel?) async -> DermPackContent {
        let chosen = includePhotos ? photoScans(scans) : []
        let raw: [(UUID, Date, Data)] = chosen.compactMap { scan in
            scan.sortedCaptures.first { $0.angle == .front }?.imageData.map { (scan.id, scan.createdAt, $0) }
        }
        let decoded = await shrink(raw.map { ($0.0, $0.2) })
        let photos = raw.compactMap { id, date, _ in decoded[id].map { DermPackContent.Photo(id: id, date: date, image: $0) } }
        let start = scans.first?.createdAt ?? .distantPast
        let products = RoutineHistory.all().compactMap { id, entry -> DermPackContent.Product? in
            guard let product = ProductCatalog.shared.product(id: id), entry.stoppedAt.map({ $0 >= start }) ?? true else { return nil }
            return .init(id: id, name: product.name, brand: product.brand, started: entry.startedAt, stopped: entry.stoppedAt)
        }.sorted { $0.started < $1.started }
        let firstDay = DayStamp(start, calendar: .current)
        let tagCounts = (journal?.entries ?? []).filter { $0.day >= firstDay }.reduce(into: [JournalTag: Int]()) { counts, entry in
            entry.tags.forEach { counts[$0, default: 0] += 1 }
        }
        let notes = scans.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map { ($0.createdAt, $0.notes) }
        return DermPackContent(scans: scans, photos: photos, products: products,
                               journal: tagCounts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }, notes: notes)
    }

    @concurrent
    static func shrink(_ photos: [(UUID, Data)]) async -> [UUID: UIImage] {
        var result: [UUID: UIImage] = [:]
        for (id, data) in photos {
            guard let image = UIImage(data: data) else { continue }
            let scale = DermPackContent.photoSide / max(image.size.width, image.size.height)
            let size = CGSize(width: image.size.width * min(scale, 1), height: image.size.height * min(scale, 1))
            result[id] = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        }
        return result
    }

    /// One US-letter page per view.
    @MainActor
    static func render(_ content: DermPackContent) -> URL? {
        let url = URL.temporaryDirectory.appending(path: "Skinalyze-visit-pack.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        let pages: [AnyView] = [AnyView(DermSummaryPage(content: content))]
            + (content.photos.isEmpty ? [] : [AnyView(DermPhotosPage(content: content))])
            + [AnyView(DermProductsPage(content: content))]
        for (index, page) in pages.enumerated() {
            let view = DermPageFrame(number: index + 1, of: pages.count) { page }
            let renderer = ImageRenderer(content: view.frame(width: 612, height: 792))
            context.beginPDFPage(nil)
            renderer.render { _, draw in draw(context) }
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}

/// Shared header and footer.
private struct DermPageFrame<Content: View>: View {
    let number: Int
    let of: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
            Spacer(minLength: 0)
            Divider()
            HStack {
                Text("Made with Skinalyze. Not a medical document: photos and counts of visible marks only, for discussion with a professional.")
                Spacer()
                Text("\(number) / \(of)")
            }
            .font(.system(size: 8))
        }
        .padding(36)
        .background(.white)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
    }
}

private struct DermSummaryPage: View {
    let content: DermPackContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skin tracking summary").font(.system(size: 22, weight: .bold))
            if let first = content.first, let last = content.last {
                Text("\(content.scans.count) scans from \(first.formatted(date: .long, time: .omitted)) to \(last.formatted(date: .long, time: .omitted))")
                    .font(.system(size: 11))
            }
            TrendChart(scans: content.scans).frame(height: 170)
            Text("Spots marked per area").font(.system(size: 13, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                GridRow {
                    Text("Area"); Text("First scan"); Text("Latest scan")
                }
                .font(.system(size: 10, weight: .semibold))
                ForEach(FaceZone.allCases, id: \.self) { zone in
                    GridRow {
                        Text(GuidanceCopy.zoneName(zone))
                        Text(content.scans.first.map { "\($0.zoneIndex(zone))" } ?? "–")
                        Text(content.scans.last.map { "\($0.zoneIndex(zone))" } ?? "–")
                    }
                    .font(.system(size: 10))
                }
            }
            Text("Scans").font(.system(size: 13, weight: .semibold))
            ForEach(content.scans.suffix(12)) { scan in
                HStack(alignment: .top) {
                    Text(scan.createdAt.formatted(date: .abbreviated, time: .omitted)).frame(width: 90, alignment: .leading)
                    Text("Index \(scan.breakoutIndex)").frame(width: 60, alignment: .leading)
                    Text(LesionType.allCases.filter { scan.counts[$0] > 0 }
                        .map { "\(LesionGlyph.displayName(for: $0)) \(scan.counts[$0])" }.joined(separator: ", "))
                }
                .font(.system(size: 9))
            }
        }
    }
}

private struct DermPhotosPage: View {
    let content: DermPackContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos").font(.system(size: 18, weight: .bold))
            Text("Front photos from across the period, first to latest.").font(.system(size: 10))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(content.photos) { photo in
                    VStack(spacing: 4) {
                        Image(uiImage: photo.image).resizable().scaledToFill()
                            .frame(height: 220).clipped()
                        Text(photo.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 9))
                    }
                }
            }
        }
    }
}

private struct DermProductsPage: View {
    let content: DermPackContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Products used").font(.system(size: 18, weight: .bold))
            if content.products.isEmpty {
                Text("No products recorded.").font(.system(size: 10))
            }
            ForEach(content.products) { product in
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(product.name).font(.system(size: 10, weight: .semibold))
                        Text(product.brand).font(.system(size: 9))
                    }
                    Spacer()
                    Text(product.stopped.map { "\(product.started.formatted(date: .abbreviated, time: .omitted)) – \($0.formatted(date: .abbreviated, time: .omitted))" }
                         ?? "\(product.started.formatted(date: .abbreviated, time: .omitted)) – now")
                        .font(.system(size: 9))
                }
            }
            if !content.journal.isEmpty {
                Text("Journal (days logged)").font(.system(size: 14, weight: .semibold)).padding(.top, 8)
                Text(content.journal.map { "\(JournalCopy.title($0.tag)) \($0.days)" }.joined(separator: " · "))
                    .font(.system(size: 10))
            }
            if !content.notes.isEmpty {
                Text("Notes").font(.system(size: 14, weight: .semibold)).padding(.top, 8)
                ForEach(Array(content.notes.enumerated()), id: \.offset) { _, note in
                    Text("\(note.date.formatted(date: .abbreviated, time: .omitted)): \(note.text)").font(.system(size: 9))
                }
            }
        }
    }
}

/// The Profile screen's export: Pro, with a photos switch.
struct ExportView: View {
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(JournalModel.self) private var journal: JournalModel?
    @State private var includePhotos = true
    @State private var pdfURL: URL?
    @State private var working = false
    @State private var paywall: PaywallReason?

    private var scans: [ScanSession] { allScans.filter { !$0.isDeleted && $0.modelContext != nil } }
    private var hasFullAccess: Bool { access?.policy.allows(.dermPack) ?? true }

    var body: some View {
        Form {
            Section {
                Text("A few pages for a skin appointment: your trend, each area's count, photos from across your scans, the products you used and your journal. It stays on your iPhone until you share it.")
                    .font(.ds.footnote)
                Toggle("Include photos", isOn: $includePhotos)
                    .onChange(of: includePhotos) { pdfURL = nil }
            }
            Section {
                if let pdfURL {
                    ShareLink("Share PDF", item: pdfURL)
                        .accessibilityIdentifier("sharePack")
                } else if !hasFullAccess {
                    Button("Create the pack with Pro") { paywall = .dermPack }
                } else {
                    Button {
                        working = true
                        Task {
                            let content = await DermPackBuilder.content(scans: scans, includePhotos: includePhotos, journal: journal)
                            pdfURL = DermPackBuilder.render(content)
                            working = false
                        }
                    } label: {
                        if working { ProgressView() } else { Text("Create PDF") }
                    }
                    .disabled(scans.isEmpty || working)
                    .accessibilityIdentifier("createPack")
                }
            }
        }
        .navigationTitle("Visit pack")
        .paywallSheet($paywall)
    }
}
