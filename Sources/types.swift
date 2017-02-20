indirect enum Type: CustomStringConvertible {
    typealias IdentifierWithGeneric = (Identifier, [Type])

    case ArrayType(Type)
    case DictionaryType(Type, Type)
    case FunctionType([Type], Type)
    case TupleType([Type])
    case TypeIdentifier([IdentifierWithGeneric])
    case OptionalType(Type)
    case ImplicitlyUnwrappedOptionalType(Type)
    case ProtocolComposition([[IdentifierWithGeneric]])
    case MetaProtocol(Type)
    case MetaType(Type)
    case `Any`
    case `Self`
    case Unknown

    var description: String {
        switch self {
            case let .ArrayType(inner):
                return "[\(inner)]"
            case let .DictionaryType(key, value):
                return "[\(key): \(value)]"
            case let .FunctionType(parameters, return_type):
                return "(\((parameters.map { $0.description }).joined(separator: ", "))) -> \(return_type)"
            case let .TupleType(types):
                return "(\((types.map { $0.description }).joined(separator: ", ")))"
            case let .TypeIdentifier(parts):
                return parts.map(Type.formatIdentifier).joined(separator: ".")
            case let .OptionalType(inner):
                return "\(inner)?"
            case let .ImplicitlyUnwrappedOptionalType(inner):
                return "\(inner)!"
            case let .ProtocolComposition(types):
                return (types.map { $0.map(Type.formatIdentifier).joined(separator: ".") }).joined(separator: " & ")
            case let .MetaProtocol(inner):
                return "\(inner).Protocol"
            case let .MetaType(inner):
                return "\(inner).Type"
            case .`Any`:
                return "Any"
            case .`Self`:
                return "Self"
            case .`Unknown`:
                return "Unknown"
        }
    }

    private static func formatIdentifier(identifier: Identifier, generics: [Type]) -> String {
        if !generics.isEmpty {
            return identifier.description + "<\((generics.map { $0.description }).joined(separator: ", "))>"
        }
        return identifier.description
    }

    static func Identifier(_ name: String) -> Type {
        return .TypeIdentifier([(OriginalIdentifier(name), [])])
    }
}

class Identifier: CustomStringConvertible {
    var name: String

    init(_ name: String) {
        self.name = name
    }

    var description: String {
        return self.name
    }
}

typealias OriginalIdentifier = Identifier
