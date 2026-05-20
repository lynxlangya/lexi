import SwiftUI

struct LexiToggle: View {
    @Binding var isOn: Bool
    var accent: Color = .lexiAccent

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? accent : Color.lexiInk4)
                    .frame(width: 32, height: 18)
                    .overlay {
                        Capsule()
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                    }

                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
