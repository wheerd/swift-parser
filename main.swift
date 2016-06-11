import Foundation

func relativePath(_ path: String) -> String? {
  return NSURL(fileURLWithPath: #file, isDirectory: false).URLByDeletingLastPathComponent?.URLByAppendingPathComponent(path)?.path
}

if let source = Source(path: relativePath("tests/test.swift")!) {
    var l = Lexer(source)

    for token in l.filter({ $0.type != .Whitespace }) { // tailor:disable
      print("\(token.type): \(token.content.literalString)")
    }

    for diag in l.diagnoses {
      let (lineRange, line, col) = diag.getContext()
      let range = diag.range.clamped(to: lineRange)
      let count = diag.source.characters.getCount(range: range)
      print("\(diag.source.identifier):\(line):\(col) \(diag.type): \(diag.message)")
      print(String(diag.source.characters[lineRange]))
      print(" " * (col - 1), terminator: "")
      print("^" * max(count, 1))
      if !diag.fixIts.isEmpty {
        print("Fix:")
        for fixIt in diag.fixIts {
          let (lineRange, line, col) = diag.source.getContext(index: fixIt.range.lowerBound)
          let range = fixIt.range.clamped(to: lineRange)
          let count = diag.source.characters.getCount(range: range)
          print(String(diag.source.characters[lineRange]))
          print(" " * (col - 1), terminator: "")
          print("^" * max(count, 1))
          print(" " * (col - 1), terminator: "")
          print(fixIt.replacement)
        }
      }
      if !diag.related.isEmpty {
        for related in diag.related {
          let (lineRange, line, col) = related.source.getContext(index: related.range.lowerBound)
          let range = related.range.clamped(to: lineRange)
          let count = related.source.characters.getCount(range: range)
          print("  \(related.source.identifier):\(line):\(col) \(related.type): \(related.message)")
          print("  " + String(related.source.characters[lineRange]))
          print(" " * (col + 1), terminator: "")
          print("^" * max(count, 1))
        }
      }
    }
}
