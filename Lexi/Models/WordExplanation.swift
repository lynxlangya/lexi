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
    let senses: [Sense]

    var copyText: String {
        let header = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let phonetic = (phoneticUS ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = phonetic.isEmpty ? header : "\(header) \(phonetic)"

        let lines = senses.map { sense in
            let pos = sense.pos.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = sense.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            if pos.isEmpty { return meaning }
            if meaning.isEmpty { return pos }
            return "\(pos) \(meaning)"
        }.filter { !$0.isEmpty }

        return ([firstLine] + lines).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

