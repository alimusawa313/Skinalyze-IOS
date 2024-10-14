//
//  ContentView.swift
//  Skinalyze
//
//  Created by Heical Chandra on 23/09/24.
//

import SwiftUI

struct ContentView: View {
    
    @State private var path: [String] = []

    var body: some View {
        NavigationStack{
            ChatView(path: $path)
        }
    }
}

//#Preview {
//    ContentView()
//}
