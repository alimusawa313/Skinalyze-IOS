import SwiftUI
import SkinalyzeKit

/// The user's initial on glass — opens Profile from the Mirror.
struct Avatar: View {
    let name: String

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "·")
            .font(.system(.title3, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .frame(width: 48, height: 48)
            .glassEffect(.regular.interactive(), in: Circle())
    }
}
