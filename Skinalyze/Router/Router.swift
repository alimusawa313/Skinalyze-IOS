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
        case log(isTabBarHidden: Bool)
        case camScanView
        case prodUsed(isFromStartup: Bool)
        case capturedImagesView(images: [UIImage])
        case anlyzResultView(images: [UIImage])
        case compareImagesView(selectedLogs: [Result])
        case newCompareImagesView(selectedLogs: [Result])
        case detailView(selectedLogs: Result)
        case newDetailView(selectedLogs: Result)
        case chatView(isFromStartup: Bool)
        case productUsedView(isFromStartup: Bool)
    }
    
    @Published var navPath = NavigationPath()
    
    func navigate(to destination: Destination) {
        navPath.append(destination)
    }
    
    func navigateBack() {
        //        navPath.removeLast()
        if navPath.count > 0 {
            navPath.removeLast()
        } else {
            // If there's nowhere to go back, navigate to log
            navigate(to: .log(isTabBarHidden: false))
        }
    }
    
    func navigateToRoot() {
        navPath.removeLast(navPath.count)
    }
}

