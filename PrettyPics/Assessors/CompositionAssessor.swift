//
//  CompositionAssessor.swift
//  PrettyPics
//
//  Created by PJ Loury on 12/2/24.
//


// CompositionAssessor.swift
import Photos
import Vision

class CompositionAssessor: PhotoAssessor {
    let name = "Rule of Thirds"
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
            
            // Use Vision to detect objects and faces
            let requests = [
                VNDetectFaceRectanglesRequest(),
                VNDetectRectanglesRequest()
            ]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform(requests)
            
            var interestPoints: [CGRect] = []
            
            // Collect face locations
            if let faceRequest = requests[0] as? VNDetectFaceRectanglesRequest,
               let faces = faceRequest.results {
                interestPoints.append(contentsOf: faces.map { $0.boundingBox })
            }
            
            // Collect rectangle regions (might indicate main subjects)
            if let rectRequest = requests[1] as? VNDetectRectanglesRequest,
               let rectangles = rectRequest.results {
                interestPoints.append(contentsOf: rectangles.map { $0.boundingBox })
            }
            
            // Calculate rule of thirds score
            let score = self.calculateThirdsScore(interestPoints)
            completion(score)
        }
    }
    
    private func calculateThirdsScore(_ regions: [CGRect]) -> Double {
        guard !regions.isEmpty else { return 0.0 }
        
        // Define rule of thirds lines (normalized coordinates)
        let thirdLines = [
            (0.33, 0.0, 0.33, 1.0), // vertical left
            (0.66, 0.0, 0.66, 1.0), // vertical right
            (0.0, 0.33, 1.0, 0.33), // horizontal top
            (0.0, 0.66, 1.0, 0.66)  // horizontal bottom
        ]
        
        var totalScore = 0.0
        
        // For each region, calculate distance to nearest third line or intersection
        for region in regions {
            let centerX = region.midX
            let centerY = region.midY
            
            // Calculate distances to third lines
            var minDistance = Double.infinity
            for (x1, y1, x2, y2) in thirdLines {
                let distance = pointToLineDistance(x: Double(centerX), y: Double(centerY),
                                                x1: x1, y1: y1, x2: x2, y2: y2)
                minDistance = min(minDistance, distance)
            }
            
            // Convert distance to score (closer = higher score)
            let score = 1.0 - min(minDistance * 5.0, 1.0) // Scale factor of 5 to make it more sensitive
            totalScore += score
        }
        
        return min(totalScore / Double(regions.count), 1.0)
    }
    
    private func pointToLineDistance(x: Double, y: Double, x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        let numerator = abs((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1)
        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))
        return numerator / denominator
    }
}
