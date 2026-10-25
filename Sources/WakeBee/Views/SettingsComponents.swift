import SwiftUI

struct SettingsScrollPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            AwakeGlassGroup {
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toggleStyle(AwakeGlassToggleStyle())
        .font(.body)
    }
}

struct SettingsGlassSection<Content: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 10) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .awakeGlassSurface()
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// Native selection semantics on the panel's shared glass surface.
struct SettingsMenuPicker<Selection: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Selection
    let value: String
    let width: CGFloat
    @ViewBuilder let options: Options

    var body: some View {
        Menu {
            Picker(title, selection: $selection) { options }
                .pickerStyle(.inline)
                .labelsHidden()
                // Menu checkmarks must not inherit the page's glass switch style.
                .toggleStyle(.automatic)
        } label: {
            Text(value)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .frame(width: width)
        .awakeGlassSurface(cornerRadius: 15)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
