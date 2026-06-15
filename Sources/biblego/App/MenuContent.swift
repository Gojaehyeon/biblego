import AppKit
import SwiftUI

struct MenuContent: View {
    var body: some View {
        Button("성경 검색 열기") {
            SearchPanel.shared.show()
        }

        Divider()

        SettingsLink {
            Text("설정…")
        }

        if !Permissions.accessibilityTrusted(prompt: false) {
            Button("손쉬운 사용 권한 허용…") {
                Permissions.accessibilityTrusted(prompt: true)
                Permissions.openAccessibilitySettings()
            }
        }

        Divider()

        Button("biblego 종료") {
            NSApplication.shared.terminate(nil)
        }
    }
}
