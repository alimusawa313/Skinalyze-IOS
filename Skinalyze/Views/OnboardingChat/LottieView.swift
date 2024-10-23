//
//  LottieView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/21/24.
//

//import SwiftUI
//import Lottie
//
//struct LottieView: UIViewRepresentable {
//    var filename: String
//
//    func makeUIView(context: Context) -> UIView {
//        let view = UIView(frame: .zero)
//        let animationView = AnimationView()
//        animationView.animation = Animation.named(filename)
//        animationView.contentMode = .scaleAspectFit
//        animationView.loopMode = .loop
//        animationView.play()
//        
//        animationView.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(animationView)
//        
//        // Constraints to fill the view
//        NSLayoutConstraint.activate([
//            animationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            animationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            animationView.topAnchor.constraint(equalTo: view.topAnchor),
//            animationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
//        
//        return view
//    }
//
//    func updateUIView(_ uiView: UIView, context: Context) {}
//}
