//
//  json.swift
//  JSON
//
//  Created by Nick Lockwood on 01/03/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

// MARK: API

/// JSON parsing errors
public enum JSONError: Error {
    case invalidNumber(String)
    case invalidCodePoint(String)
}

/// JSON parser
public func parseJSON(_ input: String) throws -> Any {
    let match = try json.match(input)
    return try match.transform(jsonTransform)!
}

// MARK: Implementation

// Labels
private enum Label: String {
    case null
    case boolean
    case number
    case string
    case json
    case array
    case object

    // Internal types
    case unichar
    case keyValue
}

// Consumers
private let space: Consumer<Label> = .discard(.zeroOrMore(
    .oneOrMore(" ") | .oneOrMore("\t") | "\n" | "\r"
))
private let null: Consumer<Label> = .label(.null, "null")
private let boolean: Consumer<Label> = .label(.boolean, "true" | "false")
private let digit: Consumer<Label> = .charInRange("0", "9")
private let number: Consumer<Label> = .label(.number, .flatten([
    .optional("-"),
    "0" | [.charInRange("1", "9"), .zeroOrMore(digit)],
    .optional([".", .oneOrMore(digit)]),
    .optional(["e" | "E", .optional("+" | "-"), .oneOrMore(digit)]),
]))
private let hexdigit: Consumer<Label> = digit | .charInRange("a", "f") | .charInRange("A", "F")
private let string: Consumer<Label> = .label(.string, [
    .discard("\""),
    .zeroOrMore(.any([
        [.discard("\\"), .any([
            "\"", "\\", "/",
            .replace("b", "\u{8}"),
            .replace("f", "\u{C}"),
            .replace("n", "\n"),
            .replace("r", "\r"),
            .replace("t", "\t"),
            .label(.unichar, .flatten([
                .discard("u"), hexdigit, hexdigit, hexdigit, hexdigit,
            ])),
        ])],
        .flatten(.oneOrMore(.codePoint(0 ... 33))), // Up to "
        .flatten(.oneOrMore(.codePoint(35 ... 91))), // Up to \
        .flatten(.oneOrMore(.codePoint(93 ... 0x10FFFF))), // From "
    ])),
    .discard("\""),
])
private let array: Consumer<Label> = .label(.array, [
    .discard("["),
    .optional(.interleaved(
        .reference(.json),
        .discard(",")
    )),
    .discard("]"),
])
private let object: Consumer<Label> = .label(.object, [
    .discard("{"),
    .optional(.interleaved(
        .label(.keyValue, [
            space, string, space,
            .discard(":"),
            .reference(.json),
        ]),
        .discard(",")
    )),
    .discard("}"),
])
private let json: Consumer<Label> = .label(.json, [
    space, boolean | null | number | string | object | array, space,
])

// Transform
private let jsonTransform: Consumer<Label>.Transform = { name, values in
    switch name {
    case .json:
        return values[0]
    case .boolean:
        return values[0] as! String == "true"
    case .null:
        return nil as Any? as Any
    case .string:
        return (values as! [String]).joined()
    case .number:
        let value = values[0] as! String
        guard let number = Double(value) else {
            throw JSONError.invalidNumber(value)
        }
        return number
    case .array:
        return values
    case .object:
        return Dictionary(values as! [(String, Any)]) { $1 }
    case .keyValue:
        return (values[0] as! String, values[1])
    case .unichar:
        let value = values[0] as! String
        guard let hex = UInt32(value, radix: 16),
            let char = UnicodeScalar(hex) else {
            throw JSONError.invalidCodePoint(value)
        }
        return String(char)
    }
}
