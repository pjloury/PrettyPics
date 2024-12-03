// ColorHarmonyAssessor.swift
import Photos
import CoreImage

class ColorHarmonyAssessor: PhotoAssessor {
    let name = "Color Harmony"
    let weight = 1.0
    
    func assessPhoto(_ asset: PHAsset, completion: @escaping (Double) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 500, height: 500),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let nsImage = image,
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                completion(0.0)
                return
            }
            
            let ciImage = CIImage(cgImage: cgImage)
            let context = CIContext(options: nil)
            
            // Instead of using histogram, let's analyze average colors in a grid
            let gridSize = 8
            var colorCounts: [String: Int] = [:]
            let width = cgImage.width
            let height = cgImage.height
            let blockWidth = width / gridSize
            let blockHeight = height / gridSize
            
            for x in 0..<gridSize {
                for y in 0..<gridSize {
                    let rect = CGRect(x: x * blockWidth,
                                    y: y * blockHeight,
                                    width: blockWidth,
                                    height: blockHeight)
                    
                    if let colorPixel = cgImage.cropping(to: rect) {
                        let dominantColor = self.getDominantColor(from: colorPixel)
                        colorCounts[dominantColor, default: 0] += 1
                    }
                }
            }
            
            // Calculate color variety score
            let uniqueColors = Double(colorCounts.count)
            let maxColors = Double(gridSize * gridSize)
            let varietyScore = min(uniqueColors / (maxColors / 2), 1.0)
            
            // Calculate distribution score
            let avgCount = Double(gridSize * gridSize) / Double(colorCounts.count)
            let distribution = colorCounts.values.reduce(0.0) { acc, count in
                acc + abs(Double(count) - avgCount)
            }
            let distributionScore = 1.0 - min(distribution / Double(gridSize * gridSize), 1.0)
            
            let finalScore = (varietyScore + distributionScore) / 2.0
            completion(finalScore)
        }
    }
    
    private func getDominantColor(from cgImage: CGImage) -> String {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let context = CGContext(data: &rawData,
                              width: width,
                              height: height,
                              bitsPerComponent: bitsPerComponent,
                              bytesPerRow: bytesPerRow,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var r: Int = 0
        var g: Int = 0
        var b: Int = 0
        
        for i in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
            r += Int(rawData[i])
            g += Int(rawData[i + 1])
            b += Int(rawData[i + 2])
        }
        
        let pixelCount = width * height
        r /= pixelCount
        g /= pixelCount
        b /= pixelCount
        
        // Return quantized color string
        return "\(r/32),\(g/32),\(b/32)"
    }
}
