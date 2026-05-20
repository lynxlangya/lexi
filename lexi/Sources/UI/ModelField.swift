import SwiftUI

struct ModelField: View {
    @Binding var value: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $value)
            .textFieldStyle(.roundedBorder)
            .font(LexiFont.mono(11.5))
            .controlSize(.large)
            .frame(width: 136)
    }
}
