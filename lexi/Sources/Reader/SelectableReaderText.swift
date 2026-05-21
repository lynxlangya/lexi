import AppKit
import SwiftUI

struct SelectableReaderText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let lineSpacing: CGFloat
    let foregroundColor: Color
    let selectionColor: Color
    var selectionContext: (() -> SentenceContext?)?

    func makeNSView(context: Context) -> NSTextView {
        let textView = ContextTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.selectionContext = selectionContext
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        if let textView = textView as? ContextTextView {
            textView.selectionContext = selectionContext
        }
        let attributed = attributedString()
        if textView.attributedString() != attributed {
            textView.textStorage?.setAttributedString(attributed)
        }
        textView.typingAttributes = attributes()
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(selectionColor),
            .foregroundColor: NSColor(foregroundColor)
        ]
        textView.insertionPointColor = NSColor(selectionColor)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? nsView.bounds.width
        guard width.isFinite, width > 0 else {
            return nil
        }

        return CGSize(
            width: width,
            height: measuredHeight(for: width)
        )
    }

    private func attributedString() -> NSAttributedString {
        NSAttributedString(string: text, attributes: attributes())
    }

    private func attributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        return [
            .font: font,
            .foregroundColor: NSColor(foregroundColor),
            .paragraphStyle: paragraphStyle
        ]
    }

    private func measuredHeight(for width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(attributedString: attributedString())
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        return ceil(layoutManager.usedRect(for: textContainer).height)
    }
}

final class ContextTextView: NSTextView {
    var selectionContext: (() -> SentenceContext?)?

    override func accessibilityValue() -> String? {
        selectionContext?()?.fullSentence ?? super.accessibilityValue()
    }
}
