// PhotoAssessor.swift
import Photos
import Vision
import CoreImage

protocol PhotoAssessor {
    var name: String { get }
    var weight: Double { get }
    func assessPhoto(_ asset: PHAsset, completion: @escaping (Double) -> Void)
}

extension PHImageRequestOptions {
    static var quickAnalysis: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .fast
        return options
    }
}

let ANALYSIS_IMAGE_SIZE = CGSize(width: 300, height: 300)


class BasicPhotoAssessor: PhotoAssessor {
    let name = "Basic Analysis"
    let weight = 1.0
    
    func assessPhoto(_ asset: PHAsset, completion: @escaping (Double) -> Void) {      
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 500, height: 500),
            contentMode: .aspectFit,
            options: .quickAnalysis
        ) { image, _ in
            guard let nsImage = image else {
                completion(0.0)
                return
            }
            
            guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                completion(0.0)
                return
            }
            
            let ciImage = CIImage(cgImage: cgImage)
            let context = CIContext(options: nil)
            
            // Calculate average brightness
            let extent = ciImage.extent
            let brightnessFilter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: extent)
            ])
            
            guard let outputImage = brightnessFilter?.outputImage,
                  let colorData = context.createCGImage(outputImage, from: outputImage.extent) else {
                completion(0.0)
                return
            }
            
            let dataProvider = colorData.dataProvider
            let data = dataProvider?.data
            let bytes = CFDataGetBytePtr(data)
            
            let brightness = (Double(bytes?[0] ?? 0) + Double(bytes?[1] ?? 0) + Double(bytes?[2] ?? 0)) / (255.0 * 3.0)
            
            // Score based on how close brightness is to optimal range (0.4 - 0.6)
            let score = 1.0 - min(abs(brightness - 0.5), 0.5) * 2
            completion(score)
        }
    }
}

class FaceDetectionAssessor: PhotoAssessor {
    let name = "Face Detection"
    let weight = 1.5
    
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
            
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil else {
                    completion(0.0)
                    return
                }
                
                let faceCount = request.results?.count ?? 0
                // Score based on presence of faces (1-2 faces optimal)
                let score = switch faceCount {
                case 1: 1.0    // Perfect - one face
                case 2: 0.9    // Very good - two faces
                case 3: 0.7    // Good - group shot
                case 4...: 0.5 // OK - larger group
                default: 0.2   // No faces
                }
                completion(score)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
