import SwiftUI
import UIKit
import GoogleMobileAds

// ---------------------------------------------------------------------------
// MARK: - Ad-Unit ID
// ---------------------------------------------------------------------------
/// Google's official test banner ad unit ID – always serves test ads.
/// Replace with your production ad unit ID before shipping.
let bannerAdUnitID = "ca-app-pub-3940256099940838/6111568278"

// ---------------------------------------------------------------------------
// MARK: - BannerAdView  (UIViewRepresentable)
// ---------------------------------------------------------------------------
/// A SwiftUI wrapper around GADBannerView.
/// Width is resolved at load time from the key window; the ad request is
/// deferred until the view is in the hierarchy so bounds are valid.
struct BannerAdView: UIViewRepresentable {
    @Binding var bannerHeight: CGFloat

    // ------------------------------------------------------------------
    // MARK: - Coordinator
    // ------------------------------------------------------------------
    class Coordinator: NSObject, BannerViewDelegate {
        let parent: BannerAdView

        init(parent: BannerAdView) {
            self.parent = parent
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            DispatchQueue.main.async {
                let height = cgSize(for: bannerView.adSize).height
                self.parent.bannerHeight = height > 0 ? height : bannerView.bounds.height
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
            print("Banner ad failed: \(error)")
            DispatchQueue.main.async {
                self.parent.bannerHeight = 0
            }
        }
    }

    // ------------------------------------------------------------------
    // MARK: - Container – defers ad load until it has a real width
    // ------------------------------------------------------------------
    class AdContainer: UIView {
        weak var bannerDelegate: BannerViewDelegate?
        private var loaded = false

        override func layoutSubviews() {
            super.layoutSubviews()
            guard !loaded, bounds.width > 0 else { return }
            loaded = true

            let adSize = portraitAnchoredAdaptiveBanner(width: bounds.width)
            let banner = BannerView(adSize: adSize)
            banner.adUnitID = bannerAdUnitID
            banner.rootViewController = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
                .first
            banner.delegate = bannerDelegate
            banner.frame = bounds
            banner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(banner)
            banner.load(Request())
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // ------------------------------------------------------------------
    // MARK: - UIViewRepresentable lifecycle
    // ------------------------------------------------------------------
    func makeUIView(context: Context) -> UIView {
        let container = AdContainer()
        container.bannerDelegate = context.coordinator
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
