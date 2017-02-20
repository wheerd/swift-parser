private let zero: UnicodeScalar = "0"
private let lowerA: UnicodeScalar = "a"
private let upperA: UnicodeScalar = "A"

extension UnicodeScalar {
    var isIdentifierHead: Bool {
        get {
            if self.isASCII {
                switch self {
                    case "a"..."z", "A"..."Z", "_":
                        return true
                    default:
                        return false
                }
            }

            switch self {
                case "\u{00A8}", "\u{00AA}", "\u{00AD}", "\u{00AF}", "\u{00B2}"..."\u{00B5}", "\u{00B7}"..."\u{00BA}",
                     "\u{00BC}"..."\u{00BE}", "\u{00C0}"..."\u{00D6}", "\u{00D8}"..."\u{00F6}", "\u{00F8}"..."\u{00FF}",
                     "\u{0100}"..."\u{02FF}", "\u{0370}"..."\u{167F}", "\u{1681}"..."\u{180D}", "\u{180F}"..."\u{1DBF}",
                     "\u{1E00}"..."\u{1FFF}",
                     "\u{200B}"..."\u{200D}", "\u{202A}"..."\u{202E}", "\u{203F}"..."\u{2040}", "\u{2054}", "\u{2060}"..."\u{206F}",
                     "\u{2070}"..."\u{20CF}", "\u{2100}"..."\u{218F}", "\u{2460}"..."\u{24FF}", "\u{2776}"..."\u{2793}",
                     "\u{2C00}"..."\u{2DFF}", "\u{2E80}"..."\u{2FFF}",
                     "\u{3004}"..."\u{3007}", "\u{3021}"..."\u{302F}", "\u{3031}"..."\u{303F}", "\u{3040}"..."\u{D7FF}",
                     "\u{F900}"..."\u{FD3D}", "\u{FD40}"..."\u{FDCF}", "\u{FDF0}"..."\u{FE1F}", "\u{FE30}"..."\u{FE44}",
                     "\u{FE47}"..."\u{FFFD}",
                     "\u{10000}"..."\u{1FFFD}", "\u{20000}"..."\u{2FFFD}", "\u{30000}"..."\u{3FFFD}", "\u{40000}"..."\u{4FFFD}",
                     "\u{50000}"..."\u{5FFFD}", "\u{60000}"..."\u{6FFFD}", "\u{70000}"..."\u{7FFFD}", "\u{80000}"..."\u{8FFFD}",
                     "\u{90000}"..."\u{9FFFD}", "\u{A0000}"..."\u{AFFFD}", "\u{B0000}"..."\u{BFFFD}", "\u{C0000}"..."\u{CFFFD}",
                     "\u{D0000}"..."\u{DFFFD}", "\u{E0000}"..."\u{EFFFD}":
                    return true
                default:
                    return false
            }
        }
    }

    var isIdentifierBody: Bool {
        get {
            if self.isIdentifierHead {
                return true
            }

            switch self {
                case "0"..."9",
                     "\u{0300}", "\u{036F}", "\u{1DC0}"..."\u{1DFF}", "\u{20D0}"..."\u{20FF}", "\u{FE20}"..."\u{FE2F}":
                    return true
                default:
                    return false
            }
        }
    }

    var isOperatorHead: Bool {
        get {
            if self.isASCII {
                switch self {
                    case "/", "=", "-", "+", "!", "*", "%", "<",
                    ">", "&", "|", "^", "~", "?", ".":
                        return true
                    default:
                        return false
                }
            }

            switch self {
                case "\u{00A1}"..."\u{00A7}", "\u{00A9}", "\u{00AB}", "\u{00AC}",
                     "\u{00AE}", "\u{00B0}"..."\u{00B1}", "\u{00B6}", "\u{00BB}",
                     "\u{00BF}", "\u{00D7}", "\u{00F7}", "\u{2016}"..."\u{2017}",
                     "\u{2020}"..."\u{2027}", "\u{2030}"..."\u{203E}",
                     "\u{2041}"..."\u{2053}", "\u{2055}"..."\u{205E}",
                     "\u{2190}"..."\u{23FF}", "\u{2500}"..."\u{2775}",
                     "\u{2794}"..."\u{2BFF}", "\u{2E00}"..."\u{2E7F}",
                     "\u{3001}"..."\u{3003}", "\u{3008}"..."\u{3030}":
                    return true
                default:
                    return false
            }
        }
    }

    var isOperatorBody: Bool {
        get {
            if self.isOperatorHead {
                return true
            }

            switch self {
                case "\u{0300}"..."\u{036F}",
                     "\u{1DC0}"..."\u{1DFF}",
                     "\u{20D0}"..."\u{20FF}",
                     "\u{FE00}"..."\u{FE0F}",
                     "\u{FE20}"..."\u{FE2F}",
                     "\u{E0100}"..."\u{E01EF}":
                    return true
                default:
                    return false
            }
        }
    }

    var isDigit: Bool {
        get {
            switch self {
                case "0"..."9":
                    return true
                default:
                    return false
            }
        }
    }

    var isHexDigit: Bool {
        get {
            switch self {
                case "0"..."9", "a"..."f", "A"..."F":
                    return true
                default:
                    return false
            }
        }
    }

    var decimalValue: UInt32? {
        get {
            return self.isDigit ? ((self.value - zero.value) as UInt32?) : nil
        }
    }

    var hexValue: UInt32? {
        get {
            switch self {
                case "0"..."9":
                    return self.value - zero.value
                case "a"..."f":
                    return 10 + self.value - lowerA.value
                case "A"..."F":
                    return 10 + self.value - upperA.value
                default:
                    return nil
            }
        }
    }
}

func * (str: String, times: Int) -> String {
    return (0..<times).reduce("") { $0.0 + str }
}

extension String {

    var literalString: String {
        get {
            return "\"" + self.characters.map {
                switch $0 {
                    case "\n":
                        return "\\n"
                    case "\r":
                        return "\\r"
                    case "\t":
                        return "\\t"
                    case "\"":
                        return "\\\""
                    case "\\":
                        return "\\\\"
                    default:
                        return String($0)
                }
            }.joined(separator: "") + "\""
        }
    }

}

extension String.UnicodeScalarView {

    func getCount(range: Range<String.UnicodeScalarView.Index>) -> Int {
        var count: Int = 0
        var index = range.lowerBound

        while index != range.upperBound {
            index = self.index(after: index)
            count += 1
        }

        return count
    }

}

func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
    return min(max(value, lower), upper)
}

extension String {

    var length: Int {
        return self.characters.count
    }

    subscript(i: Int) -> Character {
        return self.characters[index(startIndex, offsetBy: i)]
    }

    subscript(range: Range<Int>) -> String {
        let startOffset = clamp(range.lowerBound, lower: 0, upper: length)
        let endOffset = clamp(range.upperBound, lower: 0, upper: length)
        let start = index(startIndex, offsetBy: startOffset)
        let end = index(start, offsetBy: endOffset - startOffset)
        return self[start ..< end]
    }

}
