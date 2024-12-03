//
//  AestheticAnalyzer.swift
//  PrettyPics
//
//  Created by PJ Loury on 12/1/24.
//


// AestheticAnalyzer.swift
import SwiftUI
import Photos

class AestheticAnalyzer: ObservableObject {
    @Published var assessors: [String: (assessor: PhotoAssessor, isEnabled: Bool)] = [:]
    @Published var weights: [String: Double] = [:]
    
    init() {
        // Register default assessors
        let defaultAssessors: [PhotoAssessor] = [
            BasicPhotoAssessor(),
            FaceDetectionAssessor(),
            NatureSceneAssessor(),  // Add the new assessor
            ColorHarmonyAssessor(),
            CompositionAssessor()
        ]
        
        for assessor in defaultAssessors {
            assessors[assessor.name] = (assessor, true)
            weights[assessor.name] = assessor.weight
        }
    }
    
    func analyzePhoto(_ asset: PHAsset, completion: @escaping (Double, [String: Double]) -> Void) {
        var individualScores: [String: Double] = [:]
        var totalScore = 0.0
        var totalWeight = 0.0
        let group = DispatchGroup()
        
        for (name, assessorInfo) in assessors where assessorInfo.isEnabled {
            group.enter()
            assessorInfo.assessor.assessPhoto(asset) { score in
                individualScores[name] = score
                totalScore += score * (self.weights[name] ?? 1.0)
                totalWeight += self.weights[name] ?? 1.0
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let finalScore = totalWeight > 0 ? totalScore / totalWeight : 0
            completion(finalScore, individualScores)
        }
    }
}
