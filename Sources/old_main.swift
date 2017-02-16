import Foundation

func oldMain() throws {
  func relativePath(_ path: String) -> String {
    return URL(fileURLWithPath: #file, isDirectory: false).deletingLastPathComponent().appendingPathComponent(path).path
  }


  if let source = Source(path: relativePath("tests/precedencegroup.swift")) {
    let parser = Parser(source)
    do {
      print(try parser.parsePrecedenceGroup())
    } catch let diagnose as Diagnose {
      diagnose.display()
      print("Now at:")
      print(parser.lexer.peekNextToken())
    }
  }
}