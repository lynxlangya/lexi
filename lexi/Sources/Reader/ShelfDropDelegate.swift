import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ShelfDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let importURLs: ([URL]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [epubDropType])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let providers = info.itemProviders(for: [epubDropType])
        guard !providers.isEmpty else {
            return false
        }

        for provider in providers {
            provider.loadFileRepresentation(forTypeIdentifier: epubDropType.identifier) { url, _ in
                guard let url else {
                    return
                }

                do {
                    let destination = try BookFileStorage.copyToImportStaging(sourceURL: url)
                    DispatchQueue.main.async {
                        importURLs([destination])
                    }
                } catch {
                    DispatchQueue.main.async {
                        importURLs([])
                    }
                }
            }
        }

        return true
    }
}
