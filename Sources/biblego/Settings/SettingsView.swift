import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.insertModeKey) private var insertMode = InsertMode.paste.rawValue
    @AppStorage(AppSettings.includeReferenceKey) private var includeReference = false

    var body: some View {
        Form {
            Section("단축키") {
                KeyboardShortcuts.Recorder("검색 창 열기:", name: .openSearch)
            }

            Section("삽입") {
                Picker("삽입 방식", selection: $insertMode) {
                    Text("붙여넣기 (권장)").tag(InsertMode.paste.rawValue)
                    Text("직접 입력 (접근성)").tag(InsertMode.axDirect.rawValue)
                }
                Toggle("구절 참조 함께 삽입 (예: … (요한복음 3:16))", isOn: $includeReference)
            }

            Section("권한") {
                HStack {
                    Text(Permissions.accessibilityTrusted(prompt: false)
                         ? "손쉬운 사용 권한: 허용됨" : "손쉬운 사용 권한: 필요함")
                    Spacer()
                    Button("시스템 설정 열기") { Permissions.openAccessibilitySettings() }
                }
            }

            Section {
                Text("개역개정 본문은 대한성서공회 저작권 자료입니다. 개인적 사용 목적으로만 사용하세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
