import SwiftUI

/// Animated owl mascot that blinks and moves subtly
/// Uses 31 frames extracted from Midjourney video at 6fps
struct AnimatedOwlView: View {
    let size: CGFloat

    @State private var currentFrame = 1
    @State private var isAnimating = false
    @State private var frames: [UIImage] = []

    // Animation settings
    private let totalFrames = 31
    private let frameRate: Double = 6 // fps - matches extraction rate

    var body: some View {
        Group {
            if frames.isEmpty {
                // Fallback to static image while loading or if frames not found
                Image("LaunchLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(uiImage: frames[currentFrame - 1])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            loadFrames()
        }
        .onDisappear {
            isAnimating = false
        }
    }

    private func loadFrames() {
        // Try to load all frames
        var loadedFrames: [UIImage] = []

        for i in 1...totalFrames {
            if let image = loadFrame(i) {
                loadedFrames.append(image)
            }
        }

        // Only animate if we loaded all frames
        if loadedFrames.count == totalFrames {
            frames = loadedFrames
            startAnimation()
        } else {
            print("AnimatedOwlView: Only loaded \(loadedFrames.count)/\(totalFrames) frames, using static image")
        }
    }

    private func loadFrame(_ frameNumber: Int) -> UIImage? {
        let frameName = String(format: "owl-frame-%02d", frameNumber)

        // Try 1: Direct bundle path with OwlAnimation directory
        if let path = Bundle.main.path(forResource: frameName, ofType: "png", inDirectory: "OwlAnimation"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }

        // Try 2: Direct bundle path without directory
        if let path = Bundle.main.path(forResource: frameName, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }

        // Try 3: Named image (if added to asset catalog)
        if let image = UIImage(named: frameName) {
            return image
        }

        return nil
    }

    private func startAnimation() {
        isAnimating = true
        animateNextFrame()
    }

    private func animateNextFrame() {
        guard isAnimating, !frames.isEmpty else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + (1.0 / frameRate)) {
            currentFrame = (currentFrame % totalFrames) + 1
            animateNextFrame()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AnimatedOwlView(size: 200)
    }
}
