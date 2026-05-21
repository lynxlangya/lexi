import AppKit
import SwiftUI

struct SelectableReaderText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let lineSpacing: CGFloat
    let foregroundColor: Color
    let selectionColor: Color
    var selectionContext: (() -> SentenceContext?)?
    var onSelectionChange: ((SelectedTextContext?) -> Void)?

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
        textView.onSelectionChange = onSelectionChange
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        if let textView = textView as? ContextTextView {
            textView.selectionContext = selectionContext
            textView.onSelectionChange = onSelectionChange
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
    var onSelectionChange: ((SelectedTextContext?) -> Void)?

    override func accessibilityHelp() -> String? {
        selectionContext?()?.fullSentence ?? super.accessibilityHelp()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        notifySelectionChange()
    }

    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        notifySelectionChange()
    }

    private func notifySelectionChange() {
        let range = selectedRange()
        guard range.location != NSNotFound,
              range.length > 0,
              let stringRange = Range(range, in: string) else {
            onSelectionChange?(nil)
            return
        }

        let selected = SelectionLookupClassifier.normalizedText(String(string[stringRange]))
        guard !selected.isEmpty else {
            onSelectionChange?(nil)
            return
        }

        onSelectionChange?(
            SelectedTextContext(
                text: selected,
                anchor: firstRect(forCharacterRange: range, actualRange: nil),
                source: .reader,
                sentenceContext: selectionContext?()
            )
        )
    }
}
