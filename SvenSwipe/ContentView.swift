//
//  ContentView.swift
//  SvenSwipe
//
//  Created by Nico Stillhart on 14.01.2026.
//

import SwiftUI
import UIKit
import Combine

/// Root view for SvenSwipe.
/// - Shows a full-screen, swipeable photo card with modern, minimal UI.
/// - Handles permission, empty, and loading states.
struct ContentView: View {
    @StateObject private var viewModel = SvenSwipeViewModel()
    @State private var cardLocalDisabled: Bool = false
    @State private var showSettings: Bool = false
    @State private var adsEnabled: Bool = AdSettings.shared.adsEnabled
    @State private var bannerHeight: CGFloat = 0
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    switch viewModel.state {
                    case .loading:
                        loadingView
                    case .unauthorized:
                        unauthorizedView
                            .padding(.horizontal, 24)
                    case .noPhotos:
                        emptyView
                            .padding(.horizontal, 24)
                    case .ready:
                        contentView(size: geo.size)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .safeAreaInset(edge: .top) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .onAppear {
                    let scale = displayScale
                    let target = CGSize(width: geo.size.width * scale, height: geo.size.height * scale)
                    viewModel.onAppear(targetSize: target)
                    // Mirror persisted value into local state on appear.
                    adsEnabled = AdSettings.shared.adsEnabled
                }
            }

            // Banner-Ad am unteren Rand – nur wenn aktiviert
            if adsEnabled {
                BannerAdView(bannerHeight: $bannerHeight)
                    .frame(maxWidth: .infinity)
                    .frame(height: bannerHeight > 0 ? bannerHeight : 50)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(viewModel: viewModel)
            }
            .presentationDetents([.medium, .large])
            .onDisappear {
                // Re-sync after the sheet closes in case the toggle changed.
                adsEnabled = AdSettings.shared.adsEnabled
            }
        }
    
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("SvenSwipe")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            Spacer()
            if viewModel.pendingDeletes.count > 0 {
                Button {
                    Task { await viewModel.commitPendingDeletes() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Löschen (\(viewModel.pendingDeletes.count))")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ausstehende Löschungen bestätigen")
            }
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(10)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Einstellungen")

            Button {
                Task { await viewModel.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(10)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Neu laden")
        }
    }

    // MARK: - Main content (ready)
    private func contentView(size: CGSize) -> some View {
        VStack(spacing: 0) {
            // Instruction text at top so remaining height goes to the card.
            Text("Wische nach rechts zum Behalten, nach links zum Löschen")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // GeometryReader fills the rest of the available vertical space.
            GeometryReader { cardGeo in
                let cardWidth  = cardGeo.size.width - 32   // minus horizontal padding
                let cardHeight = cardGeo.size.height

                if let image = viewModel.currentImage {
                    let disabledBinding = Binding<Bool>(
                        get: { viewModel.isPerformingAction || cardLocalDisabled },
                        set: { cardLocalDisabled = $0 }
                    )

                    SwipeCardView(
                        image: image,
                        threshold: max(120, size.width * 0.22),
                        onDecision: { decision in
                            Task { await viewModel.performSwipe(decision: decision) }
                        },
                        isDisabled: disabledBinding
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .padding(.horizontal, 16)
                    .accessibilityHint("Nach rechts wischen zum Behalten, nach links zum Löschen")
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(ProgressView())
                        .frame(width: cardWidth, height: cardHeight)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Lade Fotos…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Unauthorized state
    private var unauthorizedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.slash")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Zugriff auf Fotos erforderlich")
                .font(.title3.weight(.semibold))
            Text("Bitte erlaube SvenSwipe den Zugriff auf deine Fotos, um sie per Swipe zu sortieren.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(role: .none) {
                    // Open system settings for the app
                    openSettings()
                } label: {
                    Label("Zu Einstellungen", systemImage: "gear")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color(.tertiarySystemBackground)))
                }

                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Label("Erneut versuchen", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color(.tertiarySystemBackground)))
                }
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Empty state
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Keine Fotos verfügbar")
                .font(.title3.weight(.semibold))
            Text("Es gibt keine weiteren Fotos zum Sortieren. Du kannst jederzeit neu laden.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Neu laden", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(.tertiarySystemBackground)))
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}



