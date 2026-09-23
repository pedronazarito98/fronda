import Foundation

struct DiffLine {
    let text: String
    let oldNumber: Int?
    let newNumber: Int?
    var number: String { newNumber.map(String.init) ?? oldNumber.map(String.init) ?? "·" }
}

struct DiffSection {
    let path: String
    let lines: [DiffLine]
    func hunk(at index: Int) -> String {
        let start = (0...index).last(where: { lines[$0].text.hasPrefix("@@") }) ?? index
        let end = ((index + 1)..<lines.count).first(where: { lines[$0].text.hasPrefix("@@") }) ?? lines.count
        return lines[start..<end].map(\.text).joined(separator: "\n")
    }
    static func parse(_ text: String) -> [DiffSection] {
        text.components(separatedBy: "diff --git ").dropFirst().map { chunk in
            let raw = chunk.components(separatedBy: "\n")
            let path = raw.first?.components(separatedBy: " b/").last ?? ""
            var old = 0
            var new = 0
            var inHunk = false
            let lines = raw.dropFirst().map { line -> DiffLine in
                if line.hasPrefix("@@") {
                    let pieces = line.split(separator: " ")
                    if pieces.count >= 3 {
                        old = Int(pieces[1].dropFirst().split(separator: ",").first ?? "0") ?? 0
                        new = Int(pieces[2].dropFirst().split(separator: ",").first ?? "0") ?? 0
                        inHunk = true
                    }
                    return DiffLine(text: line, oldNumber: nil, newNumber: nil)
                }
                guard inHunk, !line.hasPrefix("\\"), !line.isEmpty else {
                    return DiffLine(text: line, oldNumber: nil, newNumber: nil)
                }
                let oldNumber = line.hasPrefix("+") ? nil : old
                let newNumber = line.hasPrefix("-") ? nil : new
                if oldNumber != nil { old += 1 }
                if newNumber != nil { new += 1 }
                return DiffLine(text: line, oldNumber: oldNumber, newNumber: newNumber)
            }
            return DiffSection(path: path, lines: lines)
        }
    }
}
