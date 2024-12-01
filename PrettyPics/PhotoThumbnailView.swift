import SwiftUI
import Photos

struct PhotoThumbnailView: View {
    let asset: PHAsset
    var scores: [String: Double]?  // Made this a parameter
    @State private var image: NSImage?
    
    init(asset: PHAsset, scores: [String: Double]? = nil) {
        self.asset = asset
        self.scores = scores
    }
    
    private var finalScore: Double {
        guard let scores = scores else { return 0.0 }
        let totalWeight = scores.reduce(0.0) { $0 + $1.value }
        return totalWeight / Double(scores.count)
    }
    
    var body: some View {
        ZStack {
            Group {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                } else {
                    ProgressView()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.1))
                }
            }
            
            if let _ = scores {
                VStack {
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f", finalScore))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.3))
                            }
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { result, info in
            guard let image = result else { return }
            
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
}
