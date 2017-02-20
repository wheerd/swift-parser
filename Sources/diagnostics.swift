class Diagnose: Error, CustomStringConvertible {

    typealias Index = String.UnicodeScalarView.Index

    enum DiagnoseType {
        case Error, Warning, Note
    }

    struct FixIt {
        let range: SourceRange
        let replacement: String
        var source: Source {
            return range.source
        }

        var description: String {
            let (lineRange, _, col) = source.getContext(index: self.range.range.lowerBound)
            let range = self.range.range.clamped(to: lineRange)
            let count = source.length(range: range)
            return "\(source.substring(range: lineRange))\n\(" " * (col - 1))\("^" * max(count, 1))\n\(" " * (col - 1))\(replacement)"
        }
    }

    let range: SourceRange
    let message: String
    let type: DiagnoseType
    var related = [Diagnose]()
    var fixIts = [FixIt]()
    var source: Source {
        return range.source
    }

    init(_ message: String, type: DiagnoseType, range: SourceRange) {
        self.message = message
        self.type = type
        self.range = range
    }

    convenience init(_ message: String, type: DiagnoseType, at index: SourceLocation) {
        self.init(message, type: type, range: SourceRange(location: index))
    }

    func getLineNumber() -> Int {
        return range.start.lineNumber
    }

    func getColumn() -> Int {
        return range.start.column
    }

    func getContext() -> (Range<Index>, Int, Int) {
        return range.source.getContext(index: range.range.lowerBound)
    }

    @discardableResult
    func withReplaceFix(_ replacement: String, range: SourceRange? = nil) -> Diagnose {
        fixIts.append(FixIt(range: range ?? self.range, replacement: replacement))
        return self
    }

    @discardableResult
    func withReplaceFix(_ replacement: String, range: Range<Index>) -> Diagnose {
        return withReplaceFix(replacement, range: SourceRange(source: source, range: range))
    }

    @discardableResult
    func withInsertFix(_ insert: String, at location: SourceLocation) -> Diagnose {
        return withReplaceFix(insert, range: SourceRange(location: location))
    }

    @discardableResult
    func withInsertFix(_ insert: String, at index: Index) -> Diagnose {
        return withInsertFix(insert, at: SourceLocation(source: source, index: index))
    }

    @discardableResult
    func withRemoveFix(_ range: SourceRange? = nil) -> Diagnose {
        return withReplaceFix("", range: range)
    }

    @discardableResult
    func withRemoveFix(_ range: Range<Index>) -> Diagnose {
        return withRemoveFix(SourceRange(source: source, range: range))
    }

    @discardableResult
    func withNote(_ message: String, range: SourceRange) -> Diagnose {
        related.append(Diagnose(message, type: .Note, range: range))
        return self
    }

    @discardableResult
    func withNote(_ message: String, range: Range<Index>) -> Diagnose {
        return withNote(message, range: SourceRange(source: source, range: range))
    }

    var description: String {
        let (lineRange, line, col) = getContext()
        let range = self.range.range.clamped(to: lineRange)
        let count = source.length(range: range)
        var description = "\(source.identifier):\(line):\(col) \(type): \(message)\n"
        description += source.substring(range: lineRange) + "\n"
        description += " " * (col - 1)
        description += "^" * max(count, 1)
        if !fixIts.isEmpty {
            description += "\n\nFix:\n"
            description += fixIts.map{String(describing: $0)}.joined(separator: "\n")
        }
        if !related.isEmpty {
            description += "\n\n" + related.map{String(describing: $0)}.joined(separator: "\n")
        }
        return description
    }
}
