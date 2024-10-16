//
//  Router.swift
//  NavigationStackRoutePathExample
//
//  Created by Ali Haidar on 10/15/24.
//

import SwiftUI

final class Router: ObservableObject {
    
    public enum Destination: Hashable {
//        case livingroom
//        case bedroom(owner: String)
        case log
        case camScanView
        case prodUsed(isFromStartup: Bool)
        case capturedImagesView(images: [UIImage])
        case anlyzResultView(images: [UIImage])
        case compareImagesView(selectedLogs: [Result])
    }
    
    @Published var navPath = NavigationPath()
    
    func navigate(to destination: Destination) {
        navPath.append(destination)
    }
    
    func navigateBack() {
        navPath.removeLast()
    }
    
    func navigateToRoot() {
        navPath.removeLast(navPath.count)
    }
}

//enum ViewType: Hashable {
////    case second
////    case third(message: String)
//    case log
//    case camScanView
//    case capturedImagesView(images: [UIImage])
//    case anlyzResultView(images: [UIImage])
//}
