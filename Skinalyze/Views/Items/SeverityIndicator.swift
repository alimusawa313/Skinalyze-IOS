//
//  SeverityIndicator.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/11/24.
//

import SwiftUI

struct SeverityIndicator: View {
    var acneLevelScale: Int
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width - 40
    }
    
    private var indicatorPosition: CGFloat{
        let segmentWidth = screenWidth / 5
        switch acneLevelScale {
        case 0:
            return segmentWidth * CGFloat(acneLevelScale) + 10
        case 5:
            return segmentWidth * CGFloat(acneLevelScale) - 10
        default:
            return segmentWidth * CGFloat(acneLevelScale)
        }
        
    }
    
    private var textOffset: CGFloat {
        switch acneLevelScale {
        case 0:
            return (indicatorPosition - screenWidth / 2) + 23
        case 5:
            return (indicatorPosition - screenWidth / 2) - 50
        default:
            return (indicatorPosition - screenWidth / 2)
        }
    }
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .center)){
            Rectangle()
                .foregroundColor(.clear)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color(hex: "FFF3EB"), location: 0.00),
                            Gradient.Stop(color: Color(hex: "EDE3DA"), location: 0.25),
                            Gradient.Stop(color: Color(hex: "E5DAD1"), location: 0.50),
                            Gradient.Stop(color: Color(hex: "DCD2C9"), location: 0.75),
                            Gradient.Stop(color: Color(hex: "74574F"), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0, y: 0.5),
                        endPoint: UnitPoint(x: 1, y: 0.5)
                    )
                )
                .cornerRadius(10)
                .frame(width: screenWidth, height: 13)
            //                .padding(10)
            Capsule()
                .fill(.white)
                .frame(width: 4, height: 10)
                .offset(x: (indicatorPosition - screenWidth / 2) - 5)
                .overlay {
                    Capsule()
                        .stroke(style: StrokeStyle(lineWidth: 0.5))
                        .frame(width: 4, height: 10)
                        .offset(x: (indicatorPosition - screenWidth / 2) - 5)
                }
            
            
            Text(severityLevel)
                .font(Font.custom("Quattrocento Sans", size: 14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.27))
                .padding(.top, 35)
                .offset(x: textOffset)
        }
    }
    
    private var severityLevel: String {
            switch acneLevelScale {
            case 0:
                return "Healthy"
            case 1:
                return "Mild"
            case 2:
                return "Moderate"
            case 3:
                return "Severe"
            case 4:
                return "Very Severe"
            case 5:
                return "Extremely Severe"
            default:
                return "Unknown"
            }
        }
}

struct SkinLevelIndicator_Previews: PreviewProvider {
    static var previewSkinLevelScale: Int = 5
    static var previewSkinLevel: String = "Healthy"
    
    static var previews: some View {
        SeverityIndicator(acneLevelScale: previewSkinLevelScale)
    }
}
