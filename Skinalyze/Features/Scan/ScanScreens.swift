import AudioToolbox
import SwiftData
import SwiftUI
import SkinalyzeKit

/// Screens the in-place scan shows after capturing: the review of the three photos and plain messages
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
                Button("Cancel", action: close)
                    .buttonStyle(.chunky(.plain, fullWidth: false))
                Spacer()
            }
            Text("Looking good").font(.ds.display).foregroundStyle(Color.ds.ink)
            Text("Retake any angle, or analyse now.").font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
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
                            .buttonStyle(.chunky(.plain, fullWidth: false))
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            Spacer()
            if model.has3DScan {
                Label("3D scan captured", systemImage: "cube.transparent.fill")
                    .font(.ds.callout.weight(.semibold))
                    .foregroundStyle(Color.ds.ink)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .dsSurface(radius: Radius.medium)
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
            Text(title).font(.ds.title).foregroundStyle(Color.ds.ink).multilineTextAlignment(.center)
            Text(message).font(.ds.body).foregroundStyle(Color.ds.inkSecondary).multilineTextAlignment(.center)
            Spacer()
            Button(primary.0, action: primary.1).buttonStyle(.dsPrimary)
            if let secondary {
                Button(secondary.0, action: secondary.1).buttonStyle(.chunkyPlain)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 520)
    }
}
