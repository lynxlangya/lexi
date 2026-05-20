import SwiftUI

struct ShelfTitleBar: ToolbarContent {
    let bookCount: Int
    let canReturnToReader: Bool
    let returnToReader: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            VStack(alignment: .leading, spacing: 1) {
                Text("书架")
                    .font(LexiFont.sans(13))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lexiInk)

                Text("\(bookCount) 本书")
                    .font(LexiFont.sans(10.5))
                    .foregroundStyle(Color.lexiInk3)
            }
        }

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
