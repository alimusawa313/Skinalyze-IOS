import CoreGraphics

/// Keeps a detection only when several frames of the same angle agree on it (ML-PLAN M1.5), so a spot that flickers
/// in and out between frames does not flip a repeat scan's count.
public enum FrameAgreement {
    private struct Vote {
        let frame: Int
        let detection: RawDetection
    }

    /// Clusters detections across frames with `DetectionMatching` (at most one vote per frame per spot) and returns
    /// the most confident member of every cluster with at least `minVotes` votes.
    public static func consensus(_ frames: [[RawDetection]], minVotes: Int, imageSize: CGSize) -> [RawDetection] {
        let votes = frames.enumerated()
            .flatMap { frame, detections in detections.map { Vote(frame: frame, detection: $0) } }
            .sorted { $0.detection.confidence > $1.detection.confidence }
        let clusters = votes.reduce(into: [[Vote]]()) { clusters, vote in
            let match = clusters.firstIndex { cluster in
                !cluster.contains { $0.frame == vote.frame }
                    && DetectionMatching.isSameSpot(vote.detection.box, as: cluster[0].detection.box, imageSize: imageSize)
            }
            if let match {
                clusters[match].append(vote)
            } else {
                clusters.append([vote])
            }
        }
        return clusters.filter { $0.count >= minVotes }.map { $0[0].detection }
    }
}
