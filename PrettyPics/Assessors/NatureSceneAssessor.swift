// NatureSceneAssessor.swift
import Photos
import Vision

class NatureSceneAssessor: PhotoAssessor {
    let name = "Nature Scene"
    let weight = 1.0
    
    private let natureKeywords = Set([
        "mountain", "forest", "ocean", "beach", "sky",
        "landscape", "water", "field", "tree", "valley",
        "lake", "river", "sunset", "sunrise", "clouds",
        "canyon", "desert", "wilderness", "meadow", "hill"
    ])
    
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
            
            // Use Vision's built-in scene classification
            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNClassificationObservation] else {
                    completion(0.0)
                    return
                }
                
                // Get top classifications
                let topResults = results.prefix(3)
                
                // Calculate score based on nature-related classifications
                var natureScore = 0.0
                for result in topResults {
                    let words = result.identifier.lowercased()
                                            .components(separatedBy: CharacterSet(charactersIn: ",_ "))
                                            .filter { !$0.isEmpty }
                    let matchingWords = words.filter { self.natureKeywords.contains($0) }
                    if !matchingWords.isEmpty {
                        natureScore += Double(result.confidence)
                    }
                }
                
                completion(min(natureScore, 1.0))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

private extension String {
    func split(by separators: Character...) -> [String] {
        components(separatedBy: CharacterSet(charactersIn: String(separators)))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
