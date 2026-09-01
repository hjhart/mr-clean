import SwiftUI
import MrCleanCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Archive to") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.archiveRootDisplayPath)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .truncationMode(.middle)
                        HStack {
                            Button("Choose…") { model.chooseArchiveRoot() }
                            Button("Use Default") { model.resetArchiveRootToDefault() }
                                .disabled(model.archiveRoot == Paths.defaultArchiveRoot)
                        }
                    }
                }

                if let warning = model.iCloudWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .labelStyle(.titleAndIcon)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } footer: {
                Text("Each archive lands in a folder named like `\(Paths.archiveFolderName(for: Date()))`.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Reveal the archive in Finder afterwards", isOn: $model.revealAfterArchive)
                Toggle("Launch Mr Clean at login", isOn: Binding(
                    get: { model.launchesAtLogin },
                    set: { model.launchesAtLogin = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
