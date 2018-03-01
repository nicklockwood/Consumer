//
//  json.swift
//  JSON
//
//  Created by Nick Lockwood on 01/03/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

import Foundation

// JSON elements
enum Key: String {
    case null
    case bool
    case number
    case string
    case json
    case array
    case object
    // Internal types
    case unichar
    case keyValue
}

// JSON consumer
let space: Consumer<Key> = .discard(.zeroOrMore(.charInString(" \t\n\r\r\n")))
let null: Consumer<Key> = .label(.null, .string("null"))
let bool: Consumer<Key> = .label(.bool, .anyString(["true", "false"]))
let digit: Consumer<Key> = .charInRange("0", "9")
let number: Consumer<Key> = .label(.number, .sequence([
    .optional(.string("-")),
    .anyOf([
        .string("0"),
        .sequence([
            .charInRange("1", "9"),
            .zeroOrMore(digit),
        ]),
    ]),
    .optional(.sequence([
        .string("."),
        .oneOrMore(digit),
    ])),
]))
let hexdigit: Consumer<Key> = .anyOf([
    digit, .charInRange("a", "f"), .charInRange("A", "F"),
])
let string: Consumer<Key> = .label(.string, .sequence([
    .discard(.string("\"")),
    .zeroOrMore(.anyOf([
        .replace(.string("\\\""), "\""),
        .replace(.string("\\\\"), "\\"),
        .replace(.string("\\/"), "/"),
        .replace(.string("\\b"), "\u{8}"),
        .replace(.string("\\f"), "\u{C}"),
        .replace(.string("\\n"), "\n"),
        .replace(.string("\\r"), "\r"),
        .replace(.string("\\r\\n"), "\r\n"),
        .replace(.string("\\t"), "\t"),
        .label(.unichar, .sequence([
            .discard(.string("\\u")),
            hexdigit, hexdigit, hexdigit, hexdigit,
        ])),
        .charInRange(UnicodeScalar(0)!, "!"), // Up to "
        .charInRange("#", UnicodeScalar(0x10FFFF)!), // From "
    ])),
    .discard(.string("\"")),
]))
let array: Consumer<Key> = .label(.array, .sequence([
    .discard(.string("[")),
    .optional(.interleaved(.reference(.json), ",")),
    .discard(.string("]")),
]))
let object: Consumer<Key> = .label(.object, .sequence([
    .discard(.string("{")),
    .optional(.interleaved(.label(.keyValue, .sequence([
        space,
        string,
        space,
        .discard(.string(":")),
        .reference(.json),
    ])), ",")),
    .discard(.string("}")),
]))
let json: Consumer<Key> = .label(.json, .sequence([
    space,
    .anyOf([bool, null, number, string, object, array]),
    space,
]))

// JSON parsing errors
enum JSONError: Error {
    case invalidNumber(String)
    case invalidCodePoint(String)
}

// JSON tranform
let jsonTransform: (Key, Any) throws -> Any? = { name, value in
    switch name {
    case .json:
        return (value as! [Any]).first
    case .bool:
        return value as? String == "true"
    case .null:
        return nil as Any? as Any
    case .string:
        return (value as! [String]).joined()
    case .number:
        let value = (value as! [String]).joined()
        guard let number = Double(value) else {
            throw JSONError.invalidNumber(value)
        }
        return number
    case .array:
        return value as! [Any]
    case .object:
        return Dictionary(value as! [(String, Any)]) { $1 }
    case .keyValue:
        let value = value as! [Any]
        return (value[0] as! String, value[1])
    case .unichar:
        let value = (value as! [String]).joined()
        guard let hex = UInt32(value, radix: 16),
            let char = UnicodeScalar(hex) else {
            throw JSONError.invalidCodePoint(value)
        }
        return String(char)
    }
}
