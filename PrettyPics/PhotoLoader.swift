import SwiftUI
import Photos

class PhotoLoader: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var dateFilteredAssets: [PHAsset] = []
    @Published var topAssets: [(asset: PHAsset, scores: [String: Double])] = []
    @Published var analyzer = AestheticAnalyzer()
    @Published var selectionPercentage: Double = 20.0 // Default 20%
    @Published var analysisProgress: (current: Int, total: Int) = (0, 0)

    
    // Cache for storing assessment results
    private var assessmentCache: [String: [String: Double]] = [:]
    private let cacheLock = NSLock()
    
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
        
        // Apply quick filter before detailed analysis
        let filteredAssets = quickFilter(assets)
        
        DispatchQueue.main.async {
            self.dateFilteredAssets = filteredAssets
            // Clear cache when date range changes
            self.assessmentCache.removeAll()
            completion()
        }
    }
    
    private func quickFilter(_ assets: [PHAsset]) -> [PHAsset] {
        assets.filter { asset in
            // Filter out obviously bad photos
            let isReasonableSize = asset.pixelWidth >= 800 && asset.pixelHeight >= 800
            let isNotScreenshot = asset.mediaSubtypes.contains(.photoScreenshot) == false
            let hasReasonableDuration = asset.duration == 0 // Not a Live Photo
            
            return isReasonableSize && isNotScreenshot && hasReasonableDuration
        }
    }
    
    func findTopPhotos(completion: @escaping () -> Void) {
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "com.prettypics.analysis", qos: .userInitiated)
            var assetScores: [(asset: PHAsset, totalScore: Double, individualScores: [String: Double])] = []
            
            analysisProgress = (0, dateFilteredAssets.count)
            
            for (index, asset) in dateFilteredAssets.enumerated() {
                group.enter()
                
                queue.async { [weak self] in
                    guard let self = self else {
                        group.leave()
                        return
                    }
                    
                    // Check cache first
                    if let cachedScores = self.getCachedScores(for: asset) {
                        let totalScore = self.calculateTotalScore(from: cachedScores)
                        assetScores.append((asset, totalScore, cachedScores))
                        
                        DispatchQueue.main.async {
                            self.analysisProgress.current = index + 1
                        }
                        group.leave()
                        return
                    }
                    
                    // If not cached, analyze the photo
                    self.analyzer.analyzePhoto(asset) { score, individualScores in
                        self.cacheScores(individualScores, for: asset)
                        assetScores.append((asset, score, individualScores))
                        
                        DispatchQueue.main.async {
                            self.analysisProgress.current = index + 1
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                assetScores.sort { $0.totalScore > $1.totalScore }
                let topCount = max(1, Int(Double(assetScores.count) * (self.selectionPercentage / 100.0)))
                self.topAssets = Array(assetScores.prefix(topCount)).map { ($0.asset, $0.individualScores) }
                self.analysisProgress = (0, 0)  // Reset progress
                completion()
            }
        }
    
    private func getCachedScores(for asset: PHAsset) -> [String: Double]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let cachedScores = assessmentCache[asset.localIdentifier]
        
        // Check if we have scores for all enabled assessors
        let enabledAssessors = analyzer.assessors.filter { $0.value.isEnabled }.map { $0.key }
        let haveCachedScoresForAllEnabledAssessors = enabledAssessors.allSatisfy { assessorName in
            cachedScores?[assessorName] != nil
        }
        
        return haveCachedScoresForAllEnabledAssessors ? cachedScores : nil
    }
    
    private func cacheScores(_ scores: [String: Double], for asset: PHAsset) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        assessmentCache[asset.localIdentifier] = scores
    }
    
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        assessmentCache.removeAll()
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
