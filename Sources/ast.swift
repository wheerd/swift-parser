protocol ASTNode : CustomStringConvertible {
}

protocol Statement : ASTNode {

}

protocol Expression : ASTNode {

}

class BaseExpression : Expression {

    var description: String {
        get {
            preconditionFailure("This method must be overridden")
        }
    }

}

protocol Declaration : ASTNode {
    var name: String { get }
}

class BaseDeclaration : Declaration {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    var description: String {
        get {
            preconditionFailure("This method must be overridden")
        }
    }
}

protocol OperatorDeclaration : Declaration {

}

class PrefixOperatorDeclaration : BaseDeclaration, OperatorDeclaration {

    override var description: String {
        return "prefix operator \(name)"
    }

}

class PostfixOperatorDeclaration : BaseDeclaration, OperatorDeclaration {

    override var description: String {
        return "postfix operator \(name)"
    }

}

class InfixOperatorDeclaration : BaseDeclaration, OperatorDeclaration {
    let precedenceGroupName : String?

    init(_ name: String, precedenceGroup: String? = nil) {
        precedenceGroupName = precedenceGroup
        super.init(name)
    }

    override var description: String {
        if let group = precedenceGroupName {
            return "infix operator \(name): \(group)"
        }
        return "infix operator \(name)"
    }
}

enum Associativity {
    case Left, Right, None
}

class PrecedenceGroupDeclaration : BaseDeclaration {
    let `higherThan`: [Identifier]
    let `lowerThan`: [Identifier]
    let `associativity`: Associativity
    let `assignment`: Bool

    init(_ name: String, higherThan: [Identifier] = [], lowerThan: [Identifier] = [], associativity: Associativity = .None, assignment: Bool = false) {
        self.higherThan = higherThan
        self.lowerThan = lowerThan
        self.associativity = associativity
        self.assignment = assignment
        super.init(name)
    }

    override var description: String {
        var attributes = "  associativity: \(associativity)\n  assignment: \(assignment)"
        if !higherThan.isEmpty {
            attributes += "\n  higherThan: \((higherThan.map {$0.description}).joined(separator: ", "))"
        }
        if !lowerThan.isEmpty {
            attributes += "\n  lowerThan: \((lowerThan.map {$0.description}).joined(separator: ", "))"
        }
        return "precedencegroup \(name) {\n\(attributes)\n}"
    }

}