// ContentView.swift
import SwiftUI
import Photos

struct SelectedAssetInfo: Identifiable {
    let id = UUID()
    let asset: PHAsset
    let scores: [String: Double]
}

struct ContentView: View {
    @StateObject private var photoLoader = PhotoLoader()
    @State private var columns = [GridItem(.adaptive(minimum: 150))]
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var isAnalyzing = false
    @State private var showingDatePicker = true
    @State private var showingAssessmentControls = false
    //@State private var selectedAsset: (PHAsset, [String: Double])? = nil
    @State private var selectedAsset: SelectedAssetInfo? = nil

    
    var body: some View {
        NavigationStack {
            switch photoLoader.authorizationStatus {
            case .notDetermined:
                VStack(spacing: 16) {
                    Text("Photos Access Required")
                        .font(.headline)
                    Button("Request Access") {
                        photoLoader.requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .denied, .restricted:
                VStack(spacing: 16) {
                    Text("Photos Access Required")
                        .font(.headline)
                    Text("Please enable Photos access in System Settings")
                        .foregroundColor(.secondary)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .authorized, .limited:
                if showingDatePicker {
                    datePickerView
                } else {
                    resultsView
                }
            @unknown default:
                Text("Unknown authorization status")
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showingAssessmentControls) {
            AssessmentControlsView(photoLoader: photoLoader)
        }
        .sheet(item: $selectedAsset) { assetInfo in
            assetDetailView(asset: assetInfo.asset, scores: assetInfo.scores)
        }
    }
    
    private var datePickerView: some View {
        VStack(spacing: 20) {
            Text("Select Date Range")
                .font(.title)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Start Date")
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                        .labelsHidden()
                }
                
                VStack(alignment: .leading) {
                    Text("End Date")
                    DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                        .labelsHidden()
                }
            }
            .padding()
            
            HStack {
                Button {
                    analyzePhotos()
                } label: {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Analyzing...")
                        } else {
                            Text("Find Best Photos")
                        }
                    }
                    .frame(width: 150)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnalyzing)
                
                Button("Assessment Settings") {
                    showingAssessmentControls = true
                }
                .disabled(isAnalyzing)
            }
            
            if !photoLoader.dateFilteredAssets.isEmpty {
                Text("\(photoLoader.dateFilteredAssets.count) photos found in this date range")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var resultsView: some View {
        VStack {
            HStack {
                Button("← Back to Date Selection") {
                    showingDatePicker = true
                }
                Spacer()
                Text("\(photoLoader.topAssets.count) Best Photos Selected")
                    .font(.headline)
                Button("Assessment Settings") {
                    showingAssessmentControls = true
                }
            }
            .padding()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(photoLoader.topAssets, id: \.asset.localIdentifier) { assetInfo in
                        PhotoThumbnailView(asset: assetInfo.asset, scores: assetInfo.scores)
                            .frame(height: 150)
                            .onTapGesture {
                                selectedAsset = SelectedAssetInfo(asset: assetInfo.asset, scores: assetInfo.scores)
                            }
                    }
                }
                .padding()
            }
        }
    }
    
    private func assetDetailView(asset: PHAsset, scores: [String: Double]) -> some View {
        VStack {
            PhotoThumbnailView(asset: asset)
                .frame(height: 300)
                .padding()
            
            GroupBox("Assessment Scores") {
                ForEach(scores.sorted(by: { $0.key < $1.key }), id: \.key) { name, score in
                    HStack {
                        Text(name)
                        Spacer()
                        Text(String(format: "%.2f", score))
                            .monospacedDigit()
                    }
                }
            }
            .padding()
        }
        .frame(width: 400)
    }
    
    private func analyzePhotos() {
        isAnalyzing = true
        photoLoader.filterByDateRange(start: startDate, end: endDate) {
            photoLoader.findTopPhotos {
                isAnalyzing = false
                showingDatePicker = false
            }
        }
    }
}
