import Foundation

class Source {

  typealias Index = String.UnicodeScalarView.Index

  let content: String
  let identifier: String
  internal let characters: String.UnicodeScalarView
  internal let start: Index
  internal let end: Index

  init(_ content: String, identifier: String) {
    self.content = content
    self.identifier = identifier
    self.characters = content.unicodeScalars
    self.start = content.unicodeScalars.startIndex
    self.end = content.unicodeScalars.endIndex
  }

  convenience init?(path: String) {
    if let content = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) {
      self.init(String(content), identifier: path)
    } else {
      return nil
    }
  }

  func character(at index: Index) -> UnicodeScalar? {
    if index != self.end {
        return self.characters[index]
    }

    return nil
  }

  func index(after index: Index, offset: Int = 1) -> Index? {
    var index = index
    var offset = offset
    while index != self.end && offset > 0 {
      index = self.characters.index(after: index)
      offset -= 1
    }
    return index != self.end ? index : nil
  }

  func character(after index: Index, offset: Int = 1) -> UnicodeScalar? {
    if let nextIndex = self.index(after: index, offset: offset) {
      if nextIndex != self.end {
        return self.characters[nextIndex]
      }
    }

    return nil
  }

  func substring(range: Range<Index>) -> String {
    return String(characters[range])
  }

  func length(range: Range<Index>) -> Int {
    return characters.getCount(range: range)
  }

  func index(before index: Index, offset: Int = 1) -> Index? {
    if offset == 0 {
      return index
    }

    var index = index
    var offset = offset
    while index != self.start && offset > 0 {
      index = self.characters.index(before: index)
      offset -= 1
    }

    return (index != self.start || offset == 0) ? index : nil
  }

  func character(before index: Index, offset: Int = 1) -> UnicodeScalar? {
    if let prevIndex = self.index(before: index, offset: offset) {
      return self.characters[prevIndex]
    }

    return nil
  }

  func getLineNumber(index: Index) -> Int {
    var index = index
    var line: Int = 1
    var lastWasLF = false
    while index != self.start {
      index = self.characters.index(before: index)
      if self.characters[index] == "\r" && !lastWasLF {
        line += 1
      }
      if self.characters[index] == "\n" {
        lastWasLF = true
        line += 1
      } else {
        lastWasLF = false
      }
    }

    return line
  }

  func getLine(number: Int) -> String? {
    var line: String? = nil
    var currentNumber = 1
    content.enumerateLines { (currentLine, stop) in
      if currentNumber == number {
        line = currentLine
        stop = true
      }
      currentNumber += 1
    }
    return line
  }

  func getColumn(index: Index) -> Int {
    var index = index
    var col: Int = 1
    while index != self.start {
      index = self.characters.index(before: index)
      if self.characters[index] == "\r" || self.characters[index] == "\n" {
        return col
      }

      col += 1
    }

    return col
  }

  func getContext(index: Index) -> (Range<Index>, Int, Int) {
    var index = index
    var endIndex = index
    var col: Int = 1
    var line: Int = 1
    var lastWasLF = false

    while index != self.start {
      let newStartIndex = self.characters.index(before: index)
      if self.characters[newStartIndex] == "\n" {
        lastWasLF = true
        break
      }
      if self.characters[index] == "\r" {
        break
      }

      index = newStartIndex
      col += 1
    }

    let startIndex = index
    while index != self.start {
      index = self.characters.index(before: index)
      if self.characters[index] == "\r" && !lastWasLF {
        line += 1
      }
      if self.characters[index] == "\n" {
        lastWasLF = true
        line += 1
      } else {
        lastWasLF = false
      }
    }

    while endIndex != self.end && self.characters[endIndex] != "\n" && self.characters[endIndex] != "\r" {
      endIndex = self.characters.index(after: endIndex)
    }

    return (startIndex..<endIndex, line, col)
  }

}

struct SourceLocation: CustomStringConvertible {
    let source: Source
    let index: Source.Index

    var lineNumber: Int {
        return source.getLineNumber(index: index)
    }

    var column: Int {
        return source.getColumn(index: index)
    }

    var description: String {
        return "\(source.identifier):\(lineNumber):\(column)"
    }
}

extension SourceLocation: Equatable {
    static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        return lhs.source === rhs.source && lhs.index == rhs.index
    }
}

struct SourceRange: CustomStringConvertible {
    let source: Source
    let range: Range<Source.Index>

    var content: String {
      return source.substring(range: range)
    }

    var start: SourceLocation {
        return SourceLocation(source: source, index: range.lowerBound)
    }

    var end: SourceLocation {
        return SourceLocation(source: source, index: range.upperBound)
    }

    var description: String {
        let startLine = start.lineNumber
        let endLine = end.lineNumber
        if startLine == endLine {
            return "\(source.identifier):\(startLine):\(start.column)-\(end.column)"
        }
        return "\(source.identifier):\(startLine):\(start.column)-\(endLine):\(end.column)"
    }
}

extension SourceRange: Equatable {
    static func == (lhs: SourceRange, rhs: SourceRange) -> Bool {
        return lhs.source === rhs.source && lhs.range == rhs.range
    }
}

extension SourceRange {
    init(source: Source, index: Source.Index) {
      self.init(source: source, range: index..<index)
    }
    init(location: SourceLocation) {
      self.init(source: location.source, index: location.index)
    }
}
