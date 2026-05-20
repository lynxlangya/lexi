import SwiftUI

struct ShelfTitleBar: ToolbarContent {
    let canReturnToReader: Bool
    let returnToReader: () -> Void

    var body: some ToolbarContent {
        ToolbarSpacer(.flexible, placement: .primaryAction)

        ToolbarItem(placement: .primaryAction) {
            Button {
                returnToReader()
            } label: {
                Label("返回阅读", systemImage: "book")
            }
            .disabled(!canReturnToReader)
            .focusable(false)
        }
    }
}
