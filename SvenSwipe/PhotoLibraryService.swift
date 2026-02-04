import Foundation
import Photos
import UIKit

/// Service responsible for interacting with the user's photo library.
/// - Handles: permissions, fetching image assets, efficient image requests with caching, and deletion.
final class PhotoLibraryService {
    private let cachingManager = PHCachingImageManager()

    /// Request read/write authorization (required for deletion).
    /// Wraps the Photos API in `async`.
    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Get the current authorization status for read/write access.
    func currentAuthorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Fetch only image assets (no videos), newest first.
    func fetchImageAssets() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(with: options)
    }

    /// Request a display-ready image for the given asset.
    /// Uses aspectFill and high quality delivery for a crisp result.
    @discardableResult
    func requestImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        return cachingManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    /// Begin preheating images for upcoming assets to ensure smooth swipes.
    func startCaching(assets: [PHAsset], targetSize: CGSize) {
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        cachingManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    /// Stop preheating images for assets we no longer need.
    func stopCaching(assets: [PHAsset], targetSize: CGSize) {
        guard !assets.isEmpty else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        cachingManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    /// Permanently delete an asset from the user's photo library.
    func delete(asset: PHAsset) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    let err = NSError(domain: "PhotoLibraryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown deletion failure."])
                    continuation.resume(throwing: err)
                }
            })
        }
    }

    /// Permanently delete multiple assets from the user's photo library in a single batch.
    /// This will prompt the user once to confirm the deletion for the whole batch.
    func delete(assets: [PHAsset]) async throws {
        guard !assets.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    let err = NSError(
                        domain: "PhotoLibraryService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown deletion failure."]
                    )
                    continuation.resume(throwing: err)
                }
            })
        }
    }
}

