import SwiftUI

struct GenreColourRulesEditor: View {
    @Binding var rules: [GenreColorRule]
    @State private var newKeyword = ""
    @State private var newColor = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rules.indices, id: \.self) { idx in
                HStack {
                    Text(rules[idx].keyword)
                        .font(.system(size: 13))
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: rules[idx].colorHex) },
                        set: { rules[idx].colorHex = $0.hexString }
                    ))
                    .labelsHidden()
                    .frame(width: 28)
                    Button {
                        rules.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }

            HStack {
                TextField("e.g. tango", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { addRule() }
                ColorPicker("", selection: $newColor)
                    .labelsHidden()
                    .frame(width: 28)
                Button("Add") { addRule() }
                    .buttonStyle(.bordered)
                    .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addRule() {
        let kw = newKeyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty,
              !rules.contains(where: { $0.keyword.caseInsensitiveCompare(kw) == .orderedSame })
        else { return }
        rules.append(GenreColorRule(keyword: kw, colorHex: newColor.hexString))
        newKeyword = ""
    }
}
