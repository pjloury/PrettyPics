import SwiftUI
import Photos

class PhotoLoader: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var dateFilteredAssets: [PHAsset] = []
    @Published var topAssets: [(asset: PHAsset, scores: [String: Double])] = []
    @Published var analyzer = AestheticAnalyzer()
    @Published var selectionPercentage: Double = 20.0 // Default 20%
    
    // Cache for storing assessment results
    private var assessmentCache: [String: [String: Double]] = [:]  // [assetId: [assessorName: score]]
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }
    
    func filterByDateRange(start: Date, end: Date, completion: @escaping () -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            start as NSDate,
            end as NSDate
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        DispatchQueue.main.async {
            self.dateFilteredAssets = assets
            // Clear cache when date range changes
            self.assessmentCache.removeAll()
            completion()
        }
    }
    
    func findTopPhotos(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        var assetScores: [(asset: PHAsset, totalScore: Double, individualScores: [String: Double])] = []
        
        for asset in dateFilteredAssets {
            group.enter()
            
            // Check if we have cached results for all enabled assessors
            if let cachedScores = getCachedScores(for: asset) {
                // Use cached scores
                let totalScore = calculateTotalScore(from: cachedScores)
                assetScores.append((asset, totalScore, cachedScores))
                group.leave()
            } else {
                // Perform new analysis
                analyzer.analyzePhoto(asset) { [weak self] score, individualScores in
                    // Cache the results
                    self?.cacheScores(individualScores, for: asset)
                    assetScores.append((asset, score, individualScores))
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            assetScores.sort { $0.totalScore > $1.totalScore }
            let topCount = max(1, Int(Double(assetScores.count) * (self.selectionPercentage / 100.0)))
            self.topAssets = Array(assetScores.prefix(topCount)).map { ($0.asset, $0.individualScores) }
            completion()
        }
    }
    
    private func getCachedScores(for asset: PHAsset) -> [String: Double]? {
        let cachedScores = assessmentCache[asset.localIdentifier]
        
        // Check if we have scores for all enabled assessors
        let enabledAssessors = analyzer.assessors.filter { $0.value.isEnabled }.map { $0.key }
        let haveCachedScoresForAllEnabledAssessors = enabledAssessors.allSatisfy { assessorName in
            cachedScores?[assessorName] != nil
        }
        
        return haveCachedScoresForAllEnabledAssessors ? cachedScores : nil
    }
    
    private func cacheScores(_ scores: [String: Double], for asset: PHAsset) {
        assessmentCache[asset.localIdentifier] = scores
    }
    
    private func calculateTotalScore(from scores: [String: Double]) -> Double {
        var totalScore = 0.0
        var totalWeight = 0.0
        
        for (name, score) in scores {
            let weight = analyzer.weights[name] ?? 1.0
            totalScore += score * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? totalScore / totalWeight : 0
    }
}
