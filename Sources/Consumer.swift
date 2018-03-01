//
//  Consumer.swift
//  Consumer
//
//  Version 0.1.0
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

public indirect enum Consumer<Label: Hashable> {
    /// Primitives
    case string(String)
    case codePointIn(CountableClosedRange<UInt32>)

    /// Combinators
    case anyOf([Consumer])
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

public extension Consumer {
    /// Composite rules
    static func oneOrMore(_ consumer: Consumer) -> Consumer {
        return .sequence([consumer, .zeroOrMore(consumer)])
    }

    static func anyString(_ string: [String]) -> Consumer {
        return .anyOf(string.map { .string($0) })
    }

    static func charInString(_ string: String) -> Consumer {
        return .anyOf(string.map { .string(String($0)) })
    }

    static func charInRange(_ from: UnicodeScalar, _ to: UnicodeScalar) -> Consumer {
        return .codePointIn(min(from.value, to.value) ... max(from.value, to.value))
    }

    static func interleaved(_ consumer: Consumer, _ separator: Consumer) -> Consumer {
        return .sequence([.zeroOrMore(.sequence([consumer, separator])), consumer])
    }

    static func interleaved(_ consumer: Consumer, _ separator: String) -> Consumer {
        return interleaved(consumer, .discard(.string(separator)))
    }
}

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
        case let .codePointIn(range):
            return "\(escapeCodePoint(range.lowerBound)) – \(escapeCodePoint(range.upperBound))"
        case let .anyOf(consumers):
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
}

public extension Consumer {
    /// Abstract syntax tree returned by consumer
    indirect enum Match: Equatable {
        case named(Label, Match)
        case token(String, Range<Int>?)
        case node([Match])

        /// The range of the match in the original source (if known)
        public var range: Range<Int>? {
            switch self {
            case let .token(_, range):
                return range
            case let .named(_, match):
                return match.range
            case let .node(matches):
                guard let first = matches.first?.range,
                    let last = matches.last?.range else {
                    return nil
                }
                return first.lowerBound ..< last.upperBound
            }
        }

        /// Flatten match results into a single token
        public func flatten() -> Match {
            func _flatten(_ match: Match) -> String {
                switch match {
                case let .token(string, _):
                    return string
                case let .named(_, match):
                    return _flatten(match)
                case let .node(matches):
                    return matches.map(_flatten).joined()
                }
            }
            return .token(_flatten(self), range)
        }

        /// Lisp-like description of the AST
        public var description: String {
            func _description(_ match: Match, _ indent: String) -> String {
                switch match {
                case let .named(name, match):
                    return "(\(name) \(_description(match, indent)))"
                case let .token(string, _):
                    return escapeString(string)
                case let .node(matches):
                    return """
                    (
                    \(indent)    \(matches.map { _description($0, indent + "    ") }.joined(separator: "\n\(indent)    "))
                    \(indent))
                    """
                }
            }
            return _description(self, "")
        }

        /// Equatable implementation
        public static func == (lhs: Match, rhs: Match) -> Bool {
            switch (lhs, rhs) {
            case let (.named(lhs), .named(rhs)):
                return lhs == rhs
            case let (.token(lhs), .token(rhs)):
                return lhs.0 == rhs.0 && (lhs.1 == rhs.1 || rhs.1 == nil)
            case let (.node(lhs), .node(rhs)):
                return lhs == rhs
            case (.named, _), (.token, _), (.node, _):
                return false
            }
        }
    }

    /// A Parsing error
    struct Error: Swift.Error, CustomStringConvertible {
        public indirect enum Kind {
            case expected(Consumer)
            case unexpectedToken
            case custom(Swift.Error)
        }

        public var kind: Kind
        public var partialMatches: [Match]
        public var remaining: Substring.UnicodeScalarView?
        public var offset: Int?

        fileprivate init(_ kind: Kind,
                    partialMatches: [Match] = [],
                    remaining: Substring.UnicodeScalarView?) {
            self.kind = kind
            self.partialMatches = partialMatches
            self.remaining = remaining
        }

        public init(_ error: Swift.Error, offset: Int?) {
            if let error = error as? Error {
                self = error
                self.offset = self.offset ?? offset
                return
            }
            self.kind = .custom(error)
            self.partialMatches = []
            self.offset = self.offset ?? offset
        }

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

    // Internal match result
    private enum Result {
        case success(Match)
        case failure(Error)

        func map(_ fn: (Match) -> Match) -> Result {
            if case let .success(match) = self {
                return .success(fn(match))
            }
            return self
        }
    }

    /// Parse input and return matched result
    public func match(_ input: String) throws -> Match {
        var input = Substring(input).unicodeScalars
        var consumersByName = [Label: Consumer]()
        var offset = 0
        func _match(_ consumer: Consumer) -> Result {
            switch consumer {
            case let .label(name, consumer):
                consumersByName[name] = consumer
                return _match(consumer).map { .named(name, $0) }
            case let .reference(name):
                guard let consumer = consumersByName[name] else {
                    preconditionFailure("Undefined reference for consumer '\(name)'")
                }
                return _match(consumer)
            case let .string(string):
                let scalars = string.unicodeScalars
                guard input.starts(with: scalars) else {
                    return .failure(Error(.expected(consumer), remaining: input))
                }
                input.removeFirst(scalars.count)
                let newOffset = offset + scalars.count
                defer { offset = newOffset }
                return .success(.token(string, offset ..< newOffset))
            case let .codePointIn(range):
                if let char = input.first, range.contains(char.value) {
                    input.removeFirst()
                    let newOffset = offset + 1
                    defer { offset = newOffset }
                    return .success(.token(String(char), offset ..< newOffset))
                }
                return .failure(Error(.expected(consumer), remaining: input))
            case let .anyOf(consumers):
                var best: Error?
                for consumer in consumers {
                    let result = _match(consumer)
                    switch result {
                    case .success:
                        return result
                    case let .failure(error):
                        if (error.offset ?? 0) > (best?.offset ?? offset) {
                            best = error
                        }
                    }
                }
                return .failure(best ?? Error(.expected(consumer), remaining: input))
            case let .sequence(consumers):
                let start = input
                var best: Error?
                var matches = [Match]()
                for consumer in consumers {
                    let result = _match(consumer)
                    switch result {
                    case let .success(match):
                        switch match {
                        case .named, .token:
                            matches.append(match)
                        case let .node(_matches):
                            matches += _matches
                        }
                    case let .failure(error):
                        if best == nil || (error.offset ?? 0) > (best?.offset ?? 0) {
                            best = error
                        }
                        if case .optional = consumer {
                            continue
                        }
                        defer { input = start }
                        return .failure(Error(
                            best!.kind,
                            partialMatches: matches + best!.partialMatches,
                            remaining: best!.remaining
                        ))
                    }
                }
                return .success(.node(matches))
            case let .optional(consumer):
                return _match(consumer)
            case let .zeroOrMore(consumer):
                var matches = [Match]()
                while case let .success(match) = _match(consumer) {
                    switch match {
                    case .named, .token:
                        matches.append(match)
                    case let .node(_matches):
                        matches += _matches
                    }
                }
                return .success(.node(matches))
            case let .flatten(consumer):
                switch _match(consumer) {
                case let .success(match):
                    return .success(match.flatten())
                case let .failure(error):
                    if case .optional = consumer {
                        // TODO: is this the right behavior?
                        return .success(.token("", nil))
                    }
                    return .failure(error)
                }
            case let .discard(consumer):
                return _match(consumer).map { _ in .node([]) }
            case let .replace(consumer, replacement):
                return _match(consumer).map { .token(replacement, $0.range) }
            }
        }
        switch _match(self) {
        case let .success(match):
            if !input.isEmpty {
                throw Error(
                    .unexpectedToken,
                    partialMatches: [match],
                    remaining: input
                )
            }
            return match
        case let .failure(error):
            if input.isEmpty, case .optional = self {
                return .node([])
            }
            throw error
        }
    }
}

public extension Consumer.Match {
    /// Transform generic AST to application-specific form
    func transform(_ fn: (_ name: Label, _ value: Any) throws -> Any?) rethrows -> Any? {
        do {
            switch self {
            case let .token(string, _):
                return String(string)
            case let .node(matches):
                return try Array(matches.flatMap { try $0.transform(fn) })
            case let .named(name, match):
                return try match.transform(fn).flatMap { try fn(name, $0) }
            }
        } catch let error as Consumer.Error {
            throw error
        } catch {
            throw Consumer.Error(error, offset: self.range?.lowerBound)
        }
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
