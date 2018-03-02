//
//  repl.swift
//  REPL
//
//  Created by Nick Lockwood on 02/03/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

// MARK: API

public class State {
    fileprivate var variables = [String: Any]()
}

public func evaluate(_ input: String, state: State) throws -> Any? {
    return try repl.match(input).transform { label, value in
        switch label {
        case .bool:
            return value as! String == "true"
        case .number:
            return Double(value as! String) ?? 0
        case .string:
            return value as! String
        case .variable:
            return state.variables[value as! String] ?? (nil as Any? as Any)
        case .factor:
            let args = value as! [Any]
            if args[0] as? String == "-" {
                guard let value = args[1] as? Double else {
                    return Double.nan
                }
                return -value
            }
            return args[0]
        case .term, .expression:
            let args = value as! [Any]
            if args.count == 1 {
                return args[0]
            }
            let op = args[1] as! String
            guard let lhs = args[0] as? Double, let rhs = args[2] as? Double else {
                return Double.nan
            }
            switch op {
            case "+":
                return lhs + rhs
            case "-":
                return lhs - rhs
            case "*":
                return lhs * rhs
            case "/":
                return lhs / rhs
            default:
                preconditionFailure()
            }
        case .assignment:
            let args = value as! [Any]
            let lhs = args[0] as! String
            let rhs = args[1]
            state.variables[lhs] = rhs
            return rhs
        case .basic:
            return (value as! [Any]).first
        }
    }
}

// MARK: Implementation

private enum Label: String {
    case bool
    case number
    case string
    case variable
    case factor
    case term
    case expression
    case assignment
    case basic
}

// boolean
private let bool: Consumer<Label> = .label(.bool, "true" | "false")

// number
private let digit: Consumer<Label> = .charInRange("0", "9")
private let integer: Consumer<Label> = "0" | [.charInRange("1", "9"), .zeroOrMore(digit)]
private let decimal: Consumer<Label> = [integer, .optional([".", .oneOrMore(digit)])]
private let number: Consumer<Label> = .label(.number, .flatten(decimal))

// string
private let string: Consumer<Label> = .label(.string, .flatten([
    .discard("\""),
    .zeroOrMore(.any([
        .replace("\\\"", "\""),
        .replace("\\\\", "\\"),
        .replace("\\n", "\n"),
        .replace("\\r", "\r"),
        .replace("\\t", "\t"),
        .discard("\\"),
        .charInRange(UnicodeScalar(0)!, "!"), // Up to "
        .charInRange("#", UnicodeScalar(0x10FFFF)!), // From "
    ])),
    .discard("\""),
]))

// identifier
private let alpha: Consumer<Label> = .charInRange("a", "z") | .charInRange("A", "Z")
private let alphanumeric: Consumer<Label> = alpha | digit
private let identifier: Consumer<Label> = .flatten([alpha, .zeroOrMore(alphanumeric)])

// rvalues
private let space: Consumer<Label> = .discard(.zeroOrMore(.charInString(" \t\n\r")))
private let literal: Consumer<Label> = number | bool | string
private let variable: Consumer<Label> = .label(.variable, identifier)
private let subexpression: Consumer<Label> = [
    space, .discard("("), space,
    .reference(.expression),
    space, .discard(")"), space,
]
private let factor: Consumer<Label> = .label(.factor, [
    .optional("-"), space,
    literal | variable | subexpression,
])
private let term: Consumer<Label> = .label(.term, [
    factor, space, .optional(["*" | "/", space, .reference(.term)]),
])
private let expression: Consumer<Label> = .label(.expression, [
    term, space, .optional(["+" | "-", space, .reference(.expression)]),
])

// assignment
private let assignment: Consumer<Label> = .label(.assignment, [
    identifier, space, .discard("="), space, expression,
])

private let repl: Consumer<Label> = .label(.basic, [space, assignment | expression, space])
