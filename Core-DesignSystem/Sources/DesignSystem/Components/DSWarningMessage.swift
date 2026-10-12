import SwiftUI

/// Inline error banner.
///
/// The icon is decorative. VoiceOver reads the message as one element and
/// receives a polite announcement when that message appears or changes,
/// matching Android's `LiveRegionMode.Polite` warning.
public struct DSWarningMessage: View {
    let message: String

    @Environment(\.dsPoliteAnnouncement) private var announce
    @State private var announcedMessage = DSAnnouncedMessage()

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: DSConstant.small.value) {
            DSIcon.warningTriangle.image
                .foregroundColor(DSColor.Border.error)
                .accessibilityHidden(true)
            Text(message)
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.primary)
        }
        .padding(DSConstant.medium.value)
        .background(DSColor.Background.Layer.level1)
        .cornerRadius(DSConstant.small.value)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .onAppear { announceIfNeeded(message) }
        .onChange(of: message) { _, newMessage in
            announceIfNeeded(newMessage)
        }
    }

    private func announceIfNeeded(_ newMessage: String) {
        guard announcedMessage.value != newMessage else { return }
        announcedMessage.value = newMessage
        announce.post(newMessage)
    }
}

private final class DSAnnouncedMessage {
    var value: String?
}

/// VoiceOver announcement that waits until current speech finishes.
enum DSPoliteAnnouncement {
    static func attributed(_ message: String) -> AttributedString? {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .low
        return announcement
    }

    static func post(_ message: String) {
        guard let announcement = attributed(message) else { return }
        AccessibilityNotification.Announcement(announcement).post()
    }
}

struct DSPoliteAnnouncementAction {
    let post: (String) -> Void

    static let voiceOver = DSPoliteAnnouncementAction(post: DSPoliteAnnouncement.post)
}

private struct DSPoliteAnnouncementKey: EnvironmentKey {
    static let defaultValue = DSPoliteAnnouncementAction.voiceOver
}

extension EnvironmentValues {
    var dsPoliteAnnouncement: DSPoliteAnnouncementAction {
        get { self[DSPoliteAnnouncementKey.self] }
        set { self[DSPoliteAnnouncementKey.self] = newValue }
    }
}
