//
//  Consumer.swift
//  Consumer
//
//  Version 0.1.1
//
//  Created by Nick Lockwood on 01/03/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Consumer
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

// MARK: Consumer

public indirect enum Consumer<Label: Hashable>: Equatable {
    /// Primitives
    case string(String)
    case codePoint(CountableClosedRange<UInt32>)

    /// Combinators
    case any([Consumer])
    case sequence([Consumer])
    case optional(Consumer)
    case zeroOrMore(Consumer)

    /// Transforms
    case flatten(Consumer)
    case discard(Consumer)
    case replace(Consumer, String)

    /// References
    case label(Label, Consumer)
    case reference(Label)
}

// MARK: Matching

public extension Consumer {
    /// Parse input and return matched result
    func match(_ input: String) throws -> Match {
        return try _match(input)
    }

    /// Abstract syntax tree returned by consumer
    indirect enum Match: Equatable {
        case token(String, Range<Int>?)
        case node(Label?, [Match])

        /// The range of the match in the original source (if known)
        public var range: Range<Int>? { return _range }

        /// Flatten matched results into a single token
        public func flatten() -> Match { return _flatten() }

        /// Transform generic AST to application-specific form
        func transform(_ fn: Transform) rethrows -> Any? {
            return try _transform(fn)
        }
    }

    /// Closure for transforming a Match to an application-specific data type
    typealias Transform = (_ name: Label, _ values: [Any]) throws -> Any?

    /// A Parsing error
    struct Error: Swift.Error {
        public indirect enum Kind {
            case expected(Consumer)
            case unexpectedToken
            case custom(Swift.Error)
        }

        public var kind: Kind
        public var remaining: Substring.UnicodeScalarView?
        public var offset: Int?
    }
}

// MARK: Syntax sugar

extension Consumer: ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    /// Create .string() consumer from a string literal
    public init(stringLiteral: String) {
        self = .string(stringLiteral)
    }

    /// Create .sequence() consumer from an array literal
    public init(arrayLiteral: Consumer...) {
        self = .sequence(arrayLiteral)
    }

    /// Converts two consumers into an .any() consumer
    public static func | (lhs: Consumer, rhs: Consumer) -> Consumer {
        switch (lhs, rhs) {
        case let (.any(lhs), .any(rhs)):
            return .any(lhs + rhs)
        case let (.any(lhs), rhs):
            return .any(lhs + [rhs])
        case let (lhs, .any(rhs)):
            return .any([lhs] + rhs)
        case let (lhs, rhs):
            return .any([lhs, rhs])
        }
    }
}

/// MARK: Composite rules

public extension Consumer {
    /// Matches a list of one or more of the specified consumer
    static func oneOrMore(_ consumer: Consumer) -> Consumer {
        return .sequence([consumer, .zeroOrMore(consumer)])
    }

    /// Matches any character in the specified string
    /// Note: if the string contains composed characters like "\r\n" then they
    /// will be treated as a single character, not as individual unicode scalars
    static func charInString(_ string: String) -> Consumer {
        return .any(string.map { .string(String($0)) })
    }

    /// Creates a .codePoint() consumer using UnicodeScalars instead of code points
    static func charInRange(_ from: UnicodeScalar, _ to: UnicodeScalar) -> Consumer {
        return .codePoint(min(from.value, to.value) ... max(from.value, to.value))
    }

    /// Matches one or more of the specified consumer, interleaved with a separator
    static func interleaved(_ consumer: Consumer, _ separator: Consumer) -> Consumer {
        return .sequence([.zeroOrMore(.sequence([consumer, separator])), consumer])
    }
}

// MARK: Consumer implementation

extension Consumer: CustomStringConvertible {
    /// Human-readable description of what consumer matches
    public var description: String {
        switch self {
        case let .label(name, _):
            return "\(name)"
        case let .reference(name):
            return "\(name)"
        case let .string(string):
            return escapeString(string)
        case let .codePoint(range):
            return "\(escapeCodePoint(range.lowerBound)) – \(escapeCodePoint(range.upperBound))"
        case let .any(consumers):
            switch consumers.count {
            case 1:
                return consumers[0].description
            case 2...:
                return "\(consumers.dropLast().map { $0.description }.joined(separator: ", ")) or \(consumers.last!)"
            default:
                return "nothing"
            }
        case let .sequence(consumers):
            return consumers.first { !$0.description.isEmpty }?.description ?? ""
        case .optional, .zeroOrMore:
            return ""
        case let .flatten(consumer),
             let .discard(consumer),
             let .replace(consumer, _):
            return consumer.description
        }
    }

    /// Equatable implementation
    public static func == (lhs: Consumer, rhs: Consumer) -> Bool {
        switch (lhs, rhs) {
        case let (.string(lhs), .string(rhs)):
            return lhs == rhs
        case let (.codePoint(lhs), .codePoint(rhs)):
            return lhs == rhs
        case let (.any(lhs), .any(rhs)),
             let (.sequence(lhs), .sequence(rhs)):
            return lhs == rhs
        case let (.optional(lhs), .optional(rhs)),
             let (.zeroOrMore(lhs), .zeroOrMore(rhs)),
             let (.flatten(lhs), .flatten(rhs)),
             let (.discard(lhs), .discard(rhs)):
            return lhs == rhs
        case let (.replace(lhs), .replace(rhs)):
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        case let (.label(lhs), .label(rhs)):
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        case let (.reference(lhs), .reference(rhs)):
            return lhs == rhs
        case (.string, _),
             (.codePoint, _),
             (.any, _),
             (.sequence, _),
             (.optional, _),
             (.zeroOrMore, _),
             (.flatten, _),
             (.discard, _),
             (.replace, _),
             (.label, _),
             (.reference, _):
            return false
        }
    }
}

private extension Consumer {
    func _match(_ input: String) throws -> Match {
        var consumersByName = [Label: Consumer]()
        let input = input.unicodeScalars
        var index = input.startIndex
        var offset = 0

        var bestIndex = input.startIndex
        var expected: Consumer?

        func _match(_ consumer: Consumer) -> Match? {
            switch consumer {
            case let .label(name, _consumer):
                consumersByName[name] = consumer
                return _match(_consumer).map { match in
                    switch match {
                    case let .node(_name, matches):
                        return .node(name, _name == nil ? matches : [match])
                    default:
                        return .node(name, [match])
                    }
                }
            case let .reference(name):
                guard let consumer = consumersByName[name] else {
                    preconditionFailure("Undefined reference for consumer '\(name)'")
                }
                return _match(consumer)
            case let .string(string):
                let scalars = string.unicodeScalars
                var newOffset = offset
                var newIndex = index
                for c in scalars {
                    guard newIndex < input.endIndex, input[newIndex] == c else {
                        if newIndex > bestIndex {
                            bestIndex = index
                            expected = consumer
                        }
                        return nil
                    }
                    newOffset += 1
                    newIndex = input.index(after: newIndex)
                }
                index = newIndex
                defer { offset = newOffset }
                return .token(string, offset ..< newOffset)
            case let .codePoint(range):
                if index < input.endIndex, range.contains(input[index].value) {
                    offset += 1
                    defer { index = input.index(after: index) }
                    return .token(String(input[index]), offset - 1 ..< offset)
                }
                return nil
            case let .any(consumers):
                for consumer in consumers {
                    if let match = _match(consumer) {
                        return match
                    }
                }
                return nil
            case let .sequence(consumers):
                let start = index
                var matches = [Match]()
                for consumer in consumers {
                    if let match = _match(consumer) {
                        switch match {
                        case let .node(name, _matches):
                            if name != nil {
                                fallthrough
                            }
                            matches += _matches
                        case .token:
                            matches.append(match)
                        }
                    } else {
                        if index > bestIndex {
                            bestIndex = index
                            expected = consumer
                        }
                        index = start
                        return nil
                    }
                }
                return .node(nil, matches)
            case let .optional(consumer):
                return _match(consumer) ?? .node(nil, [])
            case let .zeroOrMore(consumer):
                var matches = [Match]()
                while let match = _match(consumer) {
                    switch match {
                    case let .node(name, _matches):
                        if name != nil {
                            fallthrough
                        }
                        matches += _matches
                    case .token:
                        matches.append(match)
                    }
                }
                return .node(nil, matches)
            case let .flatten(consumer):
                return _match(consumer)?.flatten()
            case let .discard(consumer):
                return _match(consumer).map { _ in .node(nil, []) }
            case let .replace(consumer, replacement):
                return _match(consumer).map { .token(replacement, $0.range) }
            }
        }
        if let match = _match(self) {
            if index < input.endIndex {
                throw Error(.unexpectedToken, remaining: input[index...])
            }
            return match
        } else {
            throw Error(.expected(expected ?? self), remaining: input[bestIndex...])
        }
    }
}

// MARK: Match implementation

extension Consumer.Match: CustomStringConvertible {
    /// Lisp-like description of the AST
    public var description: String {
        func _description(_ match: Consumer.Match, _ indent: String) -> String {
            switch match {
            case let .token(string, _):
                return escapeString(string)
            case let .node(name, matches):
                switch matches.count {
                case 0:
                    return name.map { "(\($0))" } ?? "()"
                case 1:
                    let description = _description(matches[0], indent)
                    return name.map { "(\($0) \(description))" } ?? description
                default:
                    return """
                    (\(name.map { "\($0)" } ?? "")
                    \(indent)    \(matches.map { _description($0, indent + "    ") }.joined(separator: "\n\(indent)    "))
                    \(indent))
                    """
                }
            }
        }
        return _description(self, "")
    }

    /// Equatable implementation
    public static func == (lhs: Consumer.Match, rhs: Consumer.Match) -> Bool {
        switch (lhs, rhs) {
        case let (.token(lhs), .token(rhs)):
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        case let (.node(lhs), .node(rhs)):
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        case (.token, _), (.node, _):
            return false
        }
    }
}

private extension Consumer.Match {
    var _range: Range<Int>? {
        switch self {
        case let .token(_, range):
            return range
        case let .node(_, matches):
            guard let first = matches.first?.range,
                let last = matches.last?.range else {
                return nil
            }
            return first.lowerBound ..< last.upperBound
        }
    }

    func _flatten() -> Consumer.Match {
        func _flatten(_ match: Consumer.Match) -> String {
            switch match {
            case let .token(string, _):
                return string
            case let .node(_, matches):
                return matches.map(_flatten).joined()
            }
        }
        return .token(_flatten(self), range)
    }

    func _transform(_ fn: Consumer.Transform) rethrows -> Any? {
        // TODO: warn if no matches are labelled, as transform won't work
        do {
            switch self {
            case let .token(string, _):
                return String(string)
            case let .node(name, matches):
                let values = try Array(matches.flatMap { try $0.transform(fn) })
                return try name.map { try fn($0, values) } ?? values
            }
        } catch let error as Consumer.Error {
            throw error
        } catch {
            throw Consumer.Error(error, offset: range?.lowerBound)
        }
    }
}

// MARK: Error implementation

extension Consumer.Error: CustomStringConvertible {
    /// Human-readable error description
    public var description: String {
        let offset = self.offset.map { " at \($0)" } ?? ""
        switch kind {
        case let .expected(consumer) where remaining?.isEmpty == true:
            return "Expected \(consumer)\(offset)"
        case .expected, .unexpectedToken:
            var token = ""
            if var remaining = self.remaining {
                while let char = remaining.popFirst(),
                    !" \t\n\r".unicodeScalars.contains(char) {
                    token.append(Character(char))
                }
            }
            return token.isEmpty ? "Unexpected token\(offset)" :
                "Unexpected token \(escapeString(token))\(offset)"
        case let .custom(error):
            return "\(error)\(offset)"
        }
    }
}

private extension Consumer.Error {
    init(_ kind: Kind, remaining: Substring.UnicodeScalarView?) {
        self.kind = kind
        self.remaining = remaining
        offset = remaining.map {
            $0.distance(from: "".startIndex, to: $0.startIndex)
        }
    }

    init(_ error: Swift.Error, offset: Int?) {
        if let error = error as? Consumer.Error {
            self = error
            self.offset = self.offset ?? offset
            return
        }
        kind = .custom(error)
        self.offset = self.offset ?? offset
        remaining = nil
    }
}

// Human-readable character
private func escapeCodePoint(_ codePoint: UInt32, inQuotes: Bool = true) -> String {
    let result: String
    switch codePoint {
    case 0:
        result = "\\0"
    case 9:
        result = "\\t"
    case 10:
        result = "\\n"
    case 13:
        result = "\\r"
    case 0x20 ..< 0x7F:
        result = String(UnicodeScalar(codePoint)!)
    default:
        var hex = String(codePoint, radix: 16, uppercase: true)
        while hex.count < 4 { hex = "0\(hex)" }
        return inQuotes ? "U+\(hex)" : hex
    }
    return inQuotes ? "'\(result)'" : result
}

// Human-readable string
private func escapeString<T: StringProtocol>(_ string: T, inQuotes: Bool = true) -> String {
    var scalars = Substring(string).unicodeScalars
    if inQuotes, scalars.count == 1 {
        return escapeCodePoint(scalars.first!.value)
    }
    var result = ""
    while let char = scalars.popFirst() {
        let escaped = escapeCodePoint(char.value, inQuotes: false)
        if escaped.count == 4 {
            result += "\\u{\(String(format: "%X", char.value))}"
        } else {
            result += escaped
        }
    }
    return inQuotes ? "\"\(result)\"" : result
}
