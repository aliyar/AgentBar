import SwiftUI

/// The popover's content. The agents' meters and conversations land here in a later milestone;
/// until then it says so.
struct PopoverView: View {
    @Environment(UpdateController.self) private var updates

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: StatusItemController.symbolName)
                    .font(.title3)
                Text("AgentBar")
                    .font(.headline)
                Spacer()
                Text(updates.currentVersion)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text("Nothing reported yet.")
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("Settings…") { AppActivation.openSettings() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 320)
    }
}

#Preview {
    PopoverView().environment(UpdateController())
}
