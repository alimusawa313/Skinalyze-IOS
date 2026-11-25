import SwiftUI
import SkinalyzeKit

/// The user's initial. Use it as the label of a round button (it opens Profile from Home).
struct Avatar: View {
    let name: String

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "·")
            .font(.system(.title3, design: .rounded).weight(.heavy))
    }
}
