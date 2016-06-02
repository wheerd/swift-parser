class Diagnose
{
  typealias Index = String.UnicodeScalarView.Index

  enum DiagnoseType
  {
    case Error, Warning, Note
  }

  struct FixIt
  {
    let range: Range<Index>
    let replacement: String
  }

  let source: Source
  let range: Range<Index>
  let message: String
  let type: DiagnoseType
  var related = [Diagnose]()
  var fixIts = [FixIt]()

  init(_ message: String, type: DiagnoseType, range: Range<Index>, source: Source)
  {
    self.message = message
    self.type = type
    self.range = range
    self.source = source
  }

  func getLine() -> Int
  {
    return self.source.getLine(index: self.range.lowerBound)
  }

  func getColumn() -> Int
  {
    return self.source.getColumn(index: self.range.lowerBound)
  }

  func getContext() -> (Range<Index>, Int, Int)
  {
    return self.source.getContext(index: self.range.lowerBound)
  }

  func withFixIt(range: Range<Index>, replacement: String) -> Diagnose
  {
    self.fixIts.append(FixIt(range: range, replacement: replacement))
    return self
  }

  func withInsertFix(at: Index, insert: String) -> Diagnose
  {
    return self.withFixIt(range: at..<at, replacement: insert)
  }

  func withRemoveFix(range: Range<Index>? = nil) -> Diagnose
  {
    return self.withFixIt(range: range ?? self.range, replacement: "")
  }

  func withNote(_ message: String, range: Range<Index>, source: Source? = nil) -> Diagnose
  {
    self.related.append(Diagnose(message, type: .Note, range: range, source: source ?? self.source))
    return self
  }
}
