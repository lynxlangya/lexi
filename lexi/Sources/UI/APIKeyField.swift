import SwiftUI

struct APIKeyField: View {
    @Binding var value: String

    var body: some View {
        SecureField("API Key", text: $value)
            .textFieldStyle(.roundedBorder)
            .font(LexiFont.mono(11.5))
            .frame(width: 190)
    }
}
