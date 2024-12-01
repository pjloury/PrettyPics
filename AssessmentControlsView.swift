import SwiftUI
import Photos

struct AssessmentControlsView: View {
    @ObservedObject var photoLoader: PhotoLoader
    @Environment(\.dismiss) private var dismiss
    @State private var isReanalyzing = false
    @State private var weights: [String: Double]
    @State private var enabledAssessors: [String: Bool]
    
    init(photoLoader: PhotoLoader) {
        self.photoLoader = photoLoader
        // Initialize state with current weights and enabled states
        _weights = State(initialValue: photoLoader.analyzer.weights)
        _enabledAssessors = State(initialValue: photoLoader.analyzer.assessors.mapValues { $0.isEnabled })
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Assessment Controls")
                .font(.title)
            
            // Enable/disable assessors
            GroupBox("Active Assessors") {
                ForEach(Array(photoLoader.analyzer.assessors.keys.sorted()), id: \.self) { name in
                    Toggle(name, isOn: Binding(
                        get: { enabledAssessors[name] ?? true },
                        set: { newValue in
                            enabledAssessors[name] = newValue
                            if let assessorInfo = photoLoader.analyzer.assessors[name] {
                                photoLoader.analyzer.assessors[name] = (assessor: assessorInfo.assessor, isEnabled: newValue)
                            }
                        }
                    ))
                    .padding(.vertical, 2)
                }
            }
            .padding()
            
            // Adjust weights
            GroupBox("Assessor Weights") {
                ForEach(Array(photoLoader.analyzer.weights.keys.sorted()), id: \.self) { name in
                    HStack {
                        Text(name)
                        Slider(
                            value: Binding(
                                get: { weights[name] ?? 1.0 },
                                set: { newValue in
                                    weights[name] = newValue
                                    photoLoader.analyzer.weights[name] = newValue
                                }
                            ),
                            in: 0.1...3.0
                        )
                        Text(String(format: "%.1f", weights[name] ?? 1.0))
                            .monospacedDigit()
                            .frame(width: 30)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            
            // Selection percentage
            GroupBox("Selection Settings") {
                HStack {
                    Text("Keep top")
                    Slider(value: $photoLoader.selectionPercentage, in: 1...50)
                    Text("\(Int(photoLoader.selectionPercentage))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
            .padding()
            
            Button {
                isReanalyzing = true
                photoLoader.findTopPhotos {
                    isReanalyzing = false
                    dismiss()
                }
            } label: {
                if isReanalyzing {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyzing...")
                    }
                    .frame(width: 150)
                } else {
                    Text("Apply Changes")
                        .frame(width: 150)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isReanalyzing)
        }
        .padding()
        .frame(width: 400)
    }
}
