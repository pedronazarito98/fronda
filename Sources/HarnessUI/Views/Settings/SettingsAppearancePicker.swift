import SwiftUI

struct SettingsAppearancePicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aparência").font(.headline)
                    Text("Escolha como a Fronda combina com seu Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Tema", selection: $selection) {
                    ForEach(["Sistema", "Claro", "Escuro"], id: \.self) { Text($0) }
                }
                .labelsHidden().fixedSize().accessibilityIdentifier("settings.appearance")
            }
            HStack(spacing: 12) {
                ForEach(["Sistema", "Claro", "Escuro"], id: \.self) { theme in
                    Button {
                        selection = theme
                    } label: {
                        VStack(spacing: 10) {
                            AppearanceWindowPreview(theme: theme)
                                .frame(height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(FrondaTheme.border, lineWidth: 1)
                                }
                            HStack(spacing: 6) {
                                Image(systemName: selection == theme ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == theme ? FrondaTheme.accent : .secondary)
                                Text(theme).font(.system(size: 12, weight: .medium))
                            }
                        }
                        .padding(10).frame(maxWidth: .infinity)
                        .background(
                            selection == theme ? FrondaTheme.accent.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13)
                                .strokeBorder(selection == theme ? FrondaTheme.accent : .clear, lineWidth: 1.5)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Aparência \(theme.lowercased())")
                    .accessibilityAddTraits(selection == theme ? .isSelected : [])
                    .accessibilityIdentifier("settings.theme." + theme)
                }
            }
            if selection == "Sistema" {
                Label("Acompanha automaticamente a aparência do macOS.", systemImage: "circle.lefthalf.filled")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 8)
    }
}

private struct AppearanceWindowPreview: View {
    let theme: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                miniature(dark: theme == "Escuro")
                if theme == "Sistema" {
                    miniature(dark: true)
                        .mask(alignment: .trailing) { Rectangle().frame(width: geometry.size.width / 2) }
                }
            }
        }.accessibilityHidden(true)
    }

    private func miniature(dark: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 3) {
                    ForEach(0..<3) { _ in Circle().fill(.secondary.opacity(0.4)).frame(width: 3, height: 3) }
                }.padding(.bottom, 4)
                RoundedRectangle(cornerRadius: 2).fill(FrondaTheme.sage.opacity(dark ? 0.6 : 0.8)).frame(height: 6)
                RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.16)).frame(height: 4)
                RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.16)).frame(height: 4)
                Spacer(minLength: 0)
            }.padding(9).frame(width: 42).background(dark ? Color(white: 0.16) : Color(white: 0.89))
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 2).fill(dark ? .white.opacity(0.6) : .black.opacity(0.5))
                    .frame(width: 35, height: 5)
                RoundedRectangle(cornerRadius: 4).fill(FrondaTheme.sage.opacity(dark ? 0.12 : 0.22)).frame(height: 20)
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3).fill(.secondary.opacity(0.12))
                }
            }.padding(10).frame(maxWidth: .infinity).background(dark ? Color(white: 0.10) : Color(white: 0.98))
        }
    }
}
