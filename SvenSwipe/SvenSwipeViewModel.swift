import SwiftUI
import Photos
import UIKit
import Combine

enum LibraryAccessState: Hashable {
    case loading
    case unauthorized
    case noPhotos
    case ready
}

enum SwipeDecision: Equatable {
    case keep
    case delete
}

/// ViewModel orchestrating permission handling, asset fetching, image loading, and swipe actions.
@MainActor
final class SvenSwipeViewModel: ObservableObject {
    @Published var state: LibraryAccessState = .loading
    @Published var currentAsset: PHAsset?
    @Published var currentImage: UIImage?
    @Published var isPerformingAction: Bool = false
    @Published var pendingDeletes: [PHAsset] = []

    /// All albums that contain at least one image. Populated after authorization succeeds.
    @Published var albums: [PhotoLibraryService.AlbumInfo] = []
    /// The currently selected album, or `nil` for the full library.
    @Published var selectedAlbum: PhotoLibraryService.AlbumInfo?

    private let service = PhotoLibraryService()
    private var fetchResult: PHFetchResult<PHAsset> = PHFetchResult()
    private var currentIndex: Int = 0

    // Prefetch window size
    private let prefetchCount = 6

    // Card target size hints (updated by view via `onAppear` with screen size)
    private var targetSize: CGSize = CGSize(width: 1200, height: 1200)

    /// Called by the view to start the flow. Also updates target size for image requests.
    func onAppear(targetSize: CGSize) {
        self.targetSize = targetSize
        Task { await self.reload() }
    }

    /// Reload authorization and assets.
    func reload() async {
        state = .loading
        let status = service.currentAuthorizationStatus()

        switch status {
        case .notDetermined:
            let newStatus = await service.requestAuthorization()
            await handle(status: newStatus)
        default:
            await handle(status: status)
        }
    }

    /// Switch to a different album (or back to the full library when `nil`).
    /// Clears pending deletes and reloads from the new source.
    func selectAlbum(_ album: PhotoLibraryService.AlbumInfo?) {
        pendingDeletes.removeAll()
        selectedAlbum = album
        Task { await reload() }
    }

    private func handle(status: PHAuthorizationStatus) async {
        guard status == .authorized || status == .limited else {
            self.state = .unauthorized
            self.currentAsset = nil
            self.currentImage = nil
            return
        }

        // Populate album list (only once; list doesn't change during a session)
        if albums.isEmpty {
            albums = service.fetchAlbums()
        }

        // Fetch photos – scoped to the selected album if one is set
        fetchResult = service.fetchImageAssets(in: selectedAlbum?.collection)
        currentIndex = 0

        guard fetchResult.count > 0 else {
            self.state = .noPhotos
            self.currentAsset = nil
            self.currentImage = nil
            return
        }

        self.state = .ready
        await requestCurrentImage()
        prefetchUpcoming()
    }

    /// Advance to next asset and load it.
    func requestNext() {
        guard state == .ready else { return }
        let nextIndex = currentIndex + 1
        guard nextIndex < fetchResult.count else {
            // No more photos
            currentAsset = nil
            currentImage = nil
            state = .noPhotos
            return
        }
        currentIndex = nextIndex
        Task { await requestCurrentImage() }
        prefetchUpcoming()
    }

    /// Execute swipe action: keep or delete.
    func performSwipe(decision: SwipeDecision) async {
        guard !isPerformingAction, state == .ready, let asset = currentAsset else { return }
        isPerformingAction = true

        switch decision {
        case .keep:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Simply advance to next
            requestNext()
            isPerformingAction = false
        case .delete:
            let notifier = UINotificationFeedbackGenerator()
            notifier.notificationOccurred(.warning)
            // Queue current asset for batch deletion and advance to next photo.
            pendingDeletes.append(asset)
            requestNext()
            isPerformingAction = false
        }
    }

    /// Queue the current asset for deletion and advance. Safe helper if you need it from the UI.
    func queueDeleteCurrentAndAdvance() {
        guard state == .ready, let asset = currentAsset else { return }
        pendingDeletes.append(asset)
        requestNext()
    }

    /// Commit all pending deletions in one batch. Shows a single system confirmation for the batch.
    func commitPendingDeletes() async {
        guard !pendingDeletes.isEmpty else { return }
        isPerformingAction = true
        do {
            try await service.delete(assets: pendingDeletes)
            pendingDeletes.removeAll()
            // After deletion, our fetch result becomes outdated; refetch for correctness.
            fetchResult = service.fetchImageAssets(in: selectedAlbum?.collection)
            if currentIndex >= fetchResult.count {
                currentAsset = nil
                currentImage = nil
                state = .noPhotos
            } else {
                await requestCurrentImage()
                prefetchUpcoming()
            }
        } catch {
            print("Batch deletion failed: \(error)")
        }
        isPerformingAction = false
    }

    /// Request the current image for display.
    private func requestCurrentImage() async {
        guard currentIndex < fetchResult.count else { return }
        let asset = fetchResult.object(at: currentIndex)
        self.currentAsset = asset
        await withCheckedContinuation { continuation in
            _ = service.requestImage(for: asset, targetSize: targetSize) { [weak self] image in
                Task { @MainActor in
                    self?.currentImage = image
                    continuation.resume()
                }
            }
        }
    }

    /// Prefetch a small window of upcoming images for smooth swipes.
    private func prefetchUpcoming() {
        guard currentIndex < fetchResult.count else { return }
        let start = currentIndex + 1
        let end = min(fetchResult.count, start + prefetchCount)
        guard start < end else { return }
        var assets: [PHAsset] = []
        assets.reserveCapacity(end - start)
        for i in start..<end {
            assets.append(fetchResult.object(at: i))
        }
        service.startCaching(assets: assets, targetSize: targetSize)
    }
}

