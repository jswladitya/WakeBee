import AppKit
import WakeBeeCore
import SwiftUI

struct LicenseView: View {
    let license: LicenseStore
    var protectionActive = false
    @State private var key = ""
    @State private var confirmRemoval = false
    @FocusState private var keyFocused: Bool

    var body: some View {
        AwakeGlassGroup {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 48, height: 48).accessibilityHidden(true)
                    VStack(spacing: 4) {
                        Text(license.isUnlocked ? "WakeBee is activated" : "Unlock WakeBee")
                            .font(.title2.weight(.semibold))
                        Text(license.isUnlocked
                             ? "Your license is saved on this Mac."
                             : "Use the key from your purchase email.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    if license.hasSavedLicense {
                        savedLicense
                    } else {
                        VStack(spacing: 12) {
                            SecureField("License key", text: $key)
                                .textFieldStyle(.roundedBorder).controlSize(.large)
                                .focused($keyFocused)
                                .accessibilityLabel("License key")
                                .onSubmit { activate() }
                                .disabled(license.isBusy)
                            Button(action: activate) {
                                HStack(spacing: 8) {
                                    if license.isBusy { ProgressView().controlSize(.small) }
                                    Text(license.isBusy ? "Activating…" : "Activate")
                                }.frame(maxWidth: .infinity)
                            }
                            .awakeGlassButton(prominent: true).buttonBorderShape(.capsule).controlSize(.large)
                            .keyboardShortcut(.defaultAction)
                            .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || license.isBusy)
                        }
                    }

                    if let error = license.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let notice = license.notice {
                        Text(notice).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !license.isUnlocked {
                    Link("Buy a license", destination: WakeBeeLicense.purchaseURL)
                        .font(.callout)
                        .accessibilityLabel("Buy a license, opens Polar checkout")
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
        }
        .defaultFocus($keyFocused, true)
        .onChange(of: license.isUnlocked) { _, unlocked in if unlocked { key = "" } }
        .confirmationDialog("Remove this Mac’s license?", isPresented: $confirmRemoval, titleVisibility: .visible) {
            Button("Remove license", role: .destructive) {
                guard !protectionActive else { return }
                Task { await license.remove() }
            }
        } message: {
            Text("WakeBee will lock until you activate a license again. Any device allocation will be released on Polar.")
        }
    }

    private var savedLicense: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(license.isUnlocked ? "Activated" : "Verification needed",
                          systemImage: license.isUnlocked ? "checkmark.seal.fill" : "key")
                        .foregroundStyle(license.isUnlocked ? Color.green : Color.secondary)
                    Spacer()
                    Text(license.maskedKey ?? "").monospaced().foregroundStyle(.secondary)
                }.font(.callout)
                if let date = license.lastValidatedAt {
                    Text("Last verified \(date, format: .dateTime.month(.abbreviated).day().hour().minute())")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            SettingsControlGroup(detail: protectionActive ? "End your current session before removing the license." : nil) {
                HStack {
                    Button(license.isBusy ? "Checking…" : "Verify license") { Task { await license.recheck() } }
                        .awakeGlassButton().buttonBorderShape(.capsule)
                        .disabled(license.isBusy)
                    Spacer()
                    Button("Remove license…") { confirmRemoval = true }
                        .awakeGlassButton().buttonBorderShape(.capsule)
                        .disabled(license.isBusy || protectionActive)
                }
            }
        }.padding(16).awakeGlassSurface()
    }

    private func activate() {
        guard !license.isBusy, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { await license.activate(key) }
    }
}
