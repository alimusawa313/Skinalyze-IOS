import AudioToolbox
import SwiftData
import SwiftUI
import SkinalyzeKit

/// Screens the in-place Mirror scan still shows over the camera: the review of the three photos and plain messages
/// (permission, failure), plus the capture sound.
// MARK: - Sound

/// The shutter sound on each capture (respects the ring/silent switch).
enum AudioCue {
    static func capture() {
        AudioServicesPlaySystemSound(1108)
    }
}

// MARK: - Review

struct ReviewScreen: View {
    let model: ScanCaptureModel
    let captured: [CaptureAngle]
    let close: () -> Void
    let analyze: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Button("Cancel", action: close).foregroundStyle(.white)
                Spacer()
            }
            Text("Looking good").font(.ds.display).foregroundStyle(.white)
            Text("Retake any angle, or analyse now.").font(.ds.body).foregroundStyle(.white.opacity(0.75))
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.md) {
                    ForEach(ScanFlow.sequence, id: \.self) { angle in
                        VStack(spacing: Spacing.xs) {
                            if let image = model.captures[angle] {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 180, height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                                    .accessibilityLabel(Text("\(GuidanceCopy.title(for: angle)) photo"))
                            }
                            Button {
                                model.retake(angle)
                            } label: {
                                Text("Retake \(GuidanceCopy.title(for: angle).lowercased())")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ds.signal)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            Spacer()
            if model.has3DScan {
                Label("3D scan captured", systemImage: "cube.transparent.fill")
                    .font(.ds.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .glassEffect(.regular, in: Capsule())
                    .accessibilityIdentifier("scan3DBadge")
            }
            Button("Analyse my skin", action: analyze)
                .buttonStyle(.dsPrimary)
                .disabled(captured.count < ScanFlow.sequence.count)
        }
        .padding(Spacing.md)
    }
}

// MARK: - Messages

struct MessageScreen: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primary: (LocalizedStringKey, () -> Void)
    var secondary: (LocalizedStringKey, () -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: systemImage).font(.system(.largeTitle)).foregroundStyle(Color.ds.signal)
                .accessibilityHidden(true)
            Text(title).font(.ds.title).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(message).font(.ds.body).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            Spacer()
            Button(primary.0, action: primary.1).buttonStyle(.dsPrimary)
            if let secondary {
                Button(secondary.0, action: secondary.1).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 520)
    }
}
