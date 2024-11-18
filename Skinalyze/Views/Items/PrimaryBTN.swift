//
//  PrimaryBTN.swift
//  Skinalyze
//
//  Created by Heical Chandra on 18/10/24.
//

import SwiftUI

struct PrimaryBTN: View {
    var text: String
    var isDisabled: Bool = false
    var action: ()-> Void
    
    init(text: String, isDisabled: Bool, action: @escaping () -> Void = {}) {
        self.text = text
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            action()
        }) {
            Text(text)
                .foregroundColor(.white)
                .fontWeight(.semibold)

                .frame(width: UIScreen.main.bounds.width - 40, height: 50)
                .background(isDisabled ? .gray : Color("btnClr"))
        }
        .disabled(isDisabled)
        
        
        .cornerRadius(100)
    }
}

#Preview {
    PrimaryBTN(text: "Take", isDisabled: false)
}
