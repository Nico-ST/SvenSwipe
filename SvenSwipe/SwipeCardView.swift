import SwiftUI
import UIKit

struct SwipeCardView: View {
    let image: UIImage
    var threshold: CGFloat = 120
    var onDecision: (SwipeDecision) -> Void
    @Binding var isDisabled: Bool

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var isAnimatingOut: Bool = false
    @State private var didCrossThreshold: Bool = false

    // Drag gesture to track user swipes.
    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isDisabled && !isAnimatingOut else { return }
                offset = value.translation
                rotation = Double(value.translation.width / 12)
                let crossed = abs(value.translation.width) > threshold
                if crossed && !didCrossThreshold {
                    // Subtle haptic when crossing threshold
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    didCrossThreshold = true
                } else if !crossed && didCrossThreshold {
                    didCrossThreshold = false
                }
            }
            .onEnded { value in
                guard !isDisabled && !isAnimatingOut else { return }
                let width = value.translation.width
                if width > threshold {
                    animateOut(to: 1000) {
                        onDecision(.keep)
                    }
                } else if width < -threshold {
                    animateOut(to: -1000) {
                        onDecision(.delete)
                    }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        offset = .zero
                        rotation = 0
                    }
                }
            }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Image content – scaledToFill within the card, clipped to bounds
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Overlays for visual feedback
                overlayView
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: offset)
            .gesture(drag)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Foto Swipe Karte")
        }
    }

    /// The colored overlay that indicates the action.
    private var overlayView: some View {
        let progress = Swift.min(abs(offset.width) / Swift.max(threshold, 1), 1)
        let isRight = offset.width > 0
        return ZStack {
            Rectangle()
                .fill((isRight ? Color.green : Color.red).opacity(0.2 * progress))
                .blendMode(.plusLighter)
            VStack {
                HStack {
                    if isRight {
                        label(icon: "checkmark.circle.fill", text: "Behalten", color: .green, progress: progress)
                        Spacer()
                    } else {
                        Spacer()
                        label(icon: "trash.fill", text: "Löschen", color: .red, progress: progress)
                    }
                }
                Spacer()
            }
            .padding(24)
        }
        .allowsHitTesting(false)
    }

    // Label view for overlay text and icon.
    private func label(icon: String, text: String, color: Color, progress: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
            Text(text)
                .font(.system(.title3, design: .rounded).weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(color.opacity(0.9))
        .background(
            Capsule()
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .opacity(Double(progress).clamped(to: 0...1))
        .scaleEffect(0.9 + 0.1 * progress)
    }

    // Animate card off-screen and then call completion.
    private func animateOut(to x: CGFloat, completion: @escaping () -> Void) {
        isAnimatingOut = true
        isDisabled = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            offset = CGSize(width: x, height: offset.height)
            rotation = Double(x / 12)
        }
        // Call completion shortly after the animation starts to keep the flow snappy.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            completion()
            // Reset for the next photo
            offset = .zero
            rotation = 0
            isAnimatingOut = false
            isDisabled = false
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
