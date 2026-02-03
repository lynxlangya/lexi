//
//  WordExplanation.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

import Foundation

struct WordExplanation: Decodable, Hashable {
    struct Sense: Decodable, Hashable, Identifiable {
        var id: String { "\(pos)::\(meaning)" }
        let pos: String
        let meaning: String
    }

    let word: String
    let phoneticUS: String?
    let web: String?
    let senses: [Sense]
}
