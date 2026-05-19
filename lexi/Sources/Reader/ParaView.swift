import SwiftUI

struct ParaView: View {
    let paragraph: DemoParagraph
    let fontSize: Double

    private var enSize: CGFloat {
        CGFloat(fontSize)
    }

    private var zhSize: CGFloat {
        CGFloat(fontSize * 13.5 / 17.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LexiSpacing.enZhGap) {
            Text(paragraph.en)
                .font(LexiFont.serif(enSize))
                .lineSpacing(enSize * 0.72)
                .foregroundStyle(Color.lexiInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(paragraph.zh)
                .font(LexiFont.zh(zhSize))
                .lineSpacing(zhSize * 0.78)
                .foregroundStyle(Color.lexiInk2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, LexiSpacing.paraGap)
    }
}
