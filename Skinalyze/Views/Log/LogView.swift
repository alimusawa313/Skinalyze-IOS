//
//  LogView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/14/24.
//

import SwiftUI
import SwiftData

struct LogView: View {
    
    @EnvironmentObject var router: Router
    @Binding var isTabBarHidden: Bool
    @State private var isComparing = false
    @Environment(\.modelContext) private var modelContext
    @Query private var logs: [Result]
    @State private var selectedLogs: [Result] = []
    
    @Namespace private var namespace
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    let groupedLogs = groupLogsByDate(logs)
                    
                    ForEach(groupedLogs.keys.sorted(by: >), id: \.self) { date in
                        LogSectionView(date: date,
                                       logs: groupedLogs[date]!,
                                       isComparing: isComparing,
                                       selectedLogs: selectedLogs,
                                       onLogTap: { log in
                            
                            if isComparing {
                                if selectedLogs.contains(log) {
                                    selectedLogs.removeAll(where: { $0.id == log.id })
                                } else if selectedLogs.count < 2 {
                                    selectedLogs.append(log)
                                }
                            } else {
                                //                                router.navigate(to: .detailView(selectedLogs: log))
                                router.navigate(to: .newDetailView(selectedLogs: log))
                            }
                        },
                                       onDelete: { offsets in
                            deleteItems(at: offsets, in: date)
                        })
                    }
                }
                .listStyle(.inset)
                .navigationTitle(isComparing ? "\(selectedLogs.count) Selected" : "Face Log")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isComparing ? "Cancel" : "Compare") {
                            withAnimation(.smooth) {
                                
                                isComparing.toggle()
                                isTabBarHidden = isComparing
                                selectedLogs = []
                            }
                        }.foregroundStyle(isComparing ? Color.red : Color("brownSecondary"))
                    }
                }
                
                if isComparing {
                    CompareButtonView(selectedLogs: selectedLogs) {
                        //                        router.navigate(to: .compareImagesView(selectedLogs: selectedLogs))
                        router.navigate(to: .newCompareImagesView(selectedLogs: selectedLogs))
                        isComparing = false
                        isTabBarHidden = isComparing
                        selectedLogs = []
                    }
                }
            }
        }
    }
    
    private func groupLogsByDate(_ logs: [Result]) -> [Date: [Result]] {
        var groupedLogs: [Date: [Result]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for log in logs {
            let dateString = dateFormatter.string(from: log.currentDate)
            let date = dateFormatter.date(from: dateString)!
            groupedLogs[date, default: []].append(log)
        }
        
        return groupedLogs
    }
    
    private func deleteItems(at offsets: IndexSet, in section: Date) {
        withAnimation {
            let logsInSection = groupLogsByDate(logs)[section]!.sorted { $0.currentDate > $1.currentDate }
            for index in offsets {
                let logToDelete = logsInSection[index]
                if let indexInAllLogs = logs.firstIndex(where: { $0.id == logToDelete.id }) {
                    modelContext.delete(logs[indexInAllLogs])
                }
            }
        }
    }
}


struct CompareButtonView: View {
    let selectedLogs: [Result]
    let onCompare: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Button {
                onCompare()
            } label: {
                HStack {
                    Spacer()
                    Text("Compare")
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding()
                .background(Capsule().foregroundStyle(Color(hex: "6F5750")))
                .padding()
            }
            .disabled(selectedLogs.count < 2)
            .opacity(selectedLogs.count < 2 ? 0.5 : 1.0)
        }
    }
}


struct LogSectionView: View {
    let date: Date
    let logs: [Result]
    let isComparing: Bool
    let selectedLogs: [Result]
    let onLogTap: (Result) -> Void
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        Section(header: Text(date, style: .date).font(.headline).foregroundStyle(Color("textPrimary"))) {
            ForEach(logs.sorted { $0.currentDate > $1.currentDate}, id: \.id ) { log in
                
                
                // Navigate to the analysis result view
                LogRowView(log: log,
                           isComparing: isComparing,
                           onTap: {
                    onLogTap(log)
                },
                           isSelected: selectedLogs.contains(log))
            }
            .onDelete(perform: onDelete)
            //            .swipeActions(edge: .trailing) {
            //                            Button(role: .destructive) {
            //                                // This is handled by the onDelete closure
            //                            } label: {
            //                                Image(systemName: "trash")
            //                            }
            //                        }
        }
        .listRowSpacing(0)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10).foregroundStyle(Color("brownPrimary").opacity(0.6))
                .padding(.horizontal)
                .padding(.vertical, 5)
        )
        .listRowSeparator(.hidden)
    }
}

struct LogRowView: View {
    let log: Result
    let isComparing: Bool
    let onTap: () -> Void
    let isSelected: Bool
    
    @Namespace private var namespace
    var body: some View {
        HStack {
            if let imageString = log.analyzedImages1, let image = imageString.toImage() {
                if #available(iOS 18.0, *) {
                    Image(uiImage: image)
                        .resizable()
                        .matchedTransitionSource(id: "thumbnailImage", in: namespace)
                        .frame(width: 85, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 85, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("No image available")
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading) {
                let severityLevel = AcneSeverityLevel(rawValue: log.geaScale)!
                HStack(alignment: .center) {
                    Text("\(log.currentDate, format: Date.FormatStyle(date: .none, time: .shortened))")
                        .font(.footnote).bold()
                    
                    Spacer()
                    
                    Text(severityLevel.description)
                        .font(.footnote).bold().foregroundStyle(Color("textReverse"))
                        .padding(EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7))
                        .background(Capsule().foregroundStyle(Color("brownSecondary")))
                }
                
                HStack {
                    Text(getDescription(for: severityLevel))
                        .lineLimit(3)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Image(systemName: "chevron.forward")
                        .opacity(isComparing ? 0 : 1)
                }
            }
        }
        .padding(EdgeInsets(top: 13, leading: 10, bottom: 13, trailing: 10))
        .overlay {
            if isComparing && isSelected {
                RoundedRectangle(cornerRadius: 10).stroke().foregroundStyle(Color("brownSecondary"))
                    .padding(.vertical, -8)
                    .padding(.horizontal, -5)
            }
        }
        .onTapGesture(perform: onTap)
    }
}

//#Preview {
//    LogView(isTabBarHidden: .constant(false))
//        .modelContainer(for: Result.self, inMemory: true)
//}


public let severityDescriptions: [Int: String] = [
    0: "The skin is clear with no signs of acne or other skin issues. It is healthy and free from inflammation or irritation.",
    1: "A few are present. Acne is infrequent and generally does not cause significant discomfort or affect daily activities.",
    2: "Several papules or pustules are present. Acne is more frequent and often involves some degree of inflammation.",
    3: "Characterized by numerous papules, pustules, or nodules (large, inflamed bumps). Severe acne can lead to scarring and significantly affect daily life.",
    4: "Very severe acne with widespread inflammation and numerous large, painful bumps. Daily life is significantly impacted, and scarring is likely.",
    5: "Extremely severe acne with severe inflammation, large cysts, and a high risk of scarring. Daily life is severely impacted, and professional treatment is necessary."
]

// Function to get the description based on the severity level
private func getDescription(for severityLevel: AcneSeverityLevel) -> String {
    return severityDescriptions[severityLevel.rawValue] ?? "Unknown severity level"
}
