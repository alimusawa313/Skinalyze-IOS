//
//  Gif Player.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/23/24.
//

import SwiftUI
import UIKit

struct GIFImage: UIViewRepresentable {
    private let data: Data?
    private let name: String?
    
    init(data: Data) {
        self.data = data
        self.name = nil
    }
    
    init(name: String) {
        self.data = nil
        self.name = name
    }
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        if let data = data {
            uiView.image = UIImage.gifImageWithData(data)
        } else if let name = name {
            uiView.image = UIImage.gifImageWithName(name)
        }
    }
}

// Extension to handle GIF loading
extension UIImage {
    static func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return UIImage.animatedImageWithSource(source)
    }
    
    static func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif"),
              let imageData = try? Data(contentsOf: bundleURL) else {
            return nil
        }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        return UIImage.animatedImageWithSource(source)
    }
    
    static func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [UIImage]()
        var duration = 0.0
        
        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: image))
                
                let delaySeconds = UIImage.delayForImageAtIndex(Int(i), source: source)
                duration += delaySeconds
            }
        }
        
        return UIImage.animatedImage(with: images, duration: duration)
    }
    
    static func delayForImageAtIndex(_ index: Int, source: CGImageSource) -> Double {
        var delay = 0.1
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties = unsafeBitCast(CFDictionaryGetValue(cfProperties,
                                                              Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
                                        to: CFDictionary.self)
        
        var delayObject: AnyObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                                       Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
                                                  to: AnyObject.self)
        
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                           Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()),
                                      to: AnyObject.self)
        }
        
        if let d = delayObject as? Double, d > 0 {
            delay = d
        }
        
        return delay
    }
}

// Resizable GIF Player View
struct ResizableGIFPlayer: View {
    let gifName: String
    @State private var scale: CGFloat = 0.33
    
    var body: some View {
        GIFImage(name: gifName)
            .frame(width: 2  * scale, height: 200 * scale)
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            scale = max(0.5, min(value, 3.0))
                        }
                    }
            )
    }
}
