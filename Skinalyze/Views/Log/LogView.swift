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
    
    @State private var isTabBarHidden: Bool?
    @State private var isComparing = false
    
    @Environment(\.modelContext) private var modelContext
    @Query private var logs: [Result]
    
    @State private var selectedLogs: [Result] = []
    
    var body: some View {
        
        NavigationView {
            ZStack {
                List {
                    let groupedLogs = groupLogsByDate(logs)
                    
                    ForEach(groupedLogs.keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(date, style: .date)) {
                            ForEach(groupedLogs[date]!, id: \.id) { log in
                                HStack {
                                    if let imageString = log.analyzedImages1, let image = imageString.toImage() {
                                        Image(uiImage: image)
                                            .resizable()
                                            .frame(width: 85, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                                .font(.footnote).bold().foregroundStyle(.white)
                                                .padding(EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7))
                                                .background(Capsule().foregroundStyle(Color(hex: "74574F")))
                                        }
                                        
                                        Text(getDescription(for: severityLevel))
                                            .lineLimit(3)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(Color(hex: "EAE3E1")))
                                .overlay {
                                    if isComparing && selectedLogs.contains(log) {
                                        RoundedRectangle(cornerRadius: 10).stroke().foregroundStyle(Color(hex: "74574F"))
                                    }
                                }
                                .onTapGesture {
                                    if isComparing {
                                        if selectedLogs.contains(log) {
                                            selectedLogs.removeAll(where: { $0.id == log.id })
                                        } else if selectedLogs.count < 2 {
                                            selectedLogs.append(log)
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }
                        .listStyle(.inset)
                        .listRowSpacing(0)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.inset)
                .listRowSpacing(0)
                .navigationTitle("FaceLog")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isComparing ? "Cancel" : "Compare") {
                            withAnimation(.smooth) {
                                
                                isComparing.toggle()
                                isTabBarHidden = isComparing
                                selectedLogs = []
                            }
                        }.foregroundStyle(isComparing ? Color.red : Color(hex: "5E0000"))
                    }
                }
                
                if isComparing {
                    withAnimation(.bouncy) {
                        VStack {
                            Spacer()
                            Button {
                                router.navigate(to: .compareImagesView(selectedLogs: selectedLogs))
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Compare")
                                    Spacer()
                                }
                                .foregroundStyle(.white)
                                .padding()
                                .background(Capsule().foregroundStyle(Color(hex: "74574F")))
                                .padding()
                            }
                            .disabled(selectedLogs.count < 2)
                            .opacity(selectedLogs.count < 2 ? 0.5 : 1.0)
                        }
                    }
                }
            }
        }
        
        //            .onAppear {
        //                printLogs()
        //            }
        
        
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
    
    private func printLogs() {
        print("Logs count: \(logs.count)")
        for log in logs {
            print("Log ID: \(log.id), Date: \(log.currentDate)")
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(logs[index])
            }
        }
    }
}

#Preview {
    LogView()
        .modelContainer(for: Result.self, inMemory: true)
}


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
