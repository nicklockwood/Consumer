//
//  ConsumerTests.swift
//  ConsumerTests
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

import Consumer
import XCTest

class ConsumerTests: XCTestCase {
    /// MARK: Primitives

    func testString() {
        let parser: Consumer<String> = .string("foo")
        XCTAssertEqual(try parser.match("foo"), .token("foo", 0 ..< 3))
        XCTAssertThrowsError(try parser.match("foobar"))
        XCTAssertThrowsError(try parser.match("barfoo"))
        XCTAssertThrowsError(try parser.match(""))
    }

    func testCharacter() {
        let parser: Consumer<String> = .character(in: "a" ... "c")
        XCTAssertEqual(try parser.match("a"), .token("a", 0 ..< 1))
        XCTAssertEqual(try parser.match("c"), .token("c", 0 ..< 1))
        XCTAssertThrowsError(try parser.match("d"))
        XCTAssertThrowsError(try parser.match("A"))
        XCTAssertThrowsError(try parser.match(""))
    }

    /// MARK: Combinators

    func testAnyOf() {
        let parser: Consumer<String> = .any([.string("foo"), .string("bar")])
        XCTAssertEqual(try parser.match("foo"), .token("foo", 0 ..< 3))
        XCTAssertEqual(try parser.match("bar"), .token("bar", 0 ..< 3))
        XCTAssertThrowsError(try parser.match("foobar"))
        XCTAssertThrowsError(try parser.match("barfoo"))
        XCTAssertThrowsError(try parser.match(""))
    }

    func testSequence() {
        let parser: Consumer<String> = .sequence([.string("foo"), .string("bar")])
        XCTAssertEqual(try parser.match("foobar"), .node(nil, [.token("foo", 0 ..< 3), .token("bar", 3 ..< 6)]))
        XCTAssertThrowsError(try parser.match("foo"))
        XCTAssertThrowsError(try parser.match("barfoo"))
        XCTAssertThrowsError(try parser.match(""))
    }

    func testOptional() {
        let parser: Consumer<String> = .optional(.string("foo"))
        XCTAssertEqual(try parser.match("foo"), .token("foo", 0 ..< 3))
        XCTAssertEqual(try parser.match(""), .node(nil, []))
        XCTAssertThrowsError(try parser.match("foobar"))
        XCTAssertThrowsError(try parser.match("barfoo"))
    }

    func testOptional2() {
        let parser: Consumer<String> = .sequence([.optional(.string("foo")), .string("bar")])
        XCTAssertEqual(try parser.match("bar"), .node(nil, [.token("bar", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("foobar"), .node(nil, [.token("foo", 0 ..< 3), .token("bar", 3 ..< 6)]))
        XCTAssertThrowsError(try parser.match("foo"))
        XCTAssertThrowsError(try parser.match("barfoo"))
        XCTAssertThrowsError(try parser.match(""))
    }

    func testZeroOrMore() {
        let parser: Consumer<String> = .zeroOrMore(.string("foo"))
        XCTAssertEqual(try parser.match("foo"), .node(nil, [.token("foo", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("foofoo"), .node(nil, [.token("foo", 0 ..< 3), .token("foo", 3 ..< 6)]))
        XCTAssertEqual(try parser.match(""), .node(nil, []))
        XCTAssertThrowsError(try parser.match("foobar"))
        XCTAssertThrowsError(try parser.match("barfoo"))
    }

    func testZeroOrMore2() {
        let parser: Consumer<String> = .zeroOrMore(.character(in: "a" ... "f"))
        XCTAssertEqual(try parser.match("abc"), .node(nil, [.token("a", 0 ..< 1), .token("b", 1 ..< 2), .token("c", 2 ..< 3)]))
    }

    /// MARK: Standard transforms

    func testFlattenOptional() {
        let parser: Consumer<String> = .flatten(.optional(.string("foo")))
        XCTAssertEqual(try parser.match("foo"), .token("foo", 0 ..< 3))
        XCTAssertEqual(try parser.match(""), .token("", 0 ..< 0))
    }

    func testFlattenAnyString() {
        let parser: Consumer<String> = .flatten("foo" | "bar")
        XCTAssertEqual(try parser.match("bar"), .token("bar", 0 ..< 3))
    }

    func testFlattenAnySequence() {
        let parser: Consumer<String> = .flatten(["a", "b"] | ["b", "a"])
        XCTAssertEqual(try parser.match("ab"), .token("ab", 0 ..< 2))
    }

    func testFlattenStringSequence() {
        let parser: Consumer<String> = .flatten(["foo", "bar"])
        XCTAssertEqual(try parser.match("foobar"), .token("foobar", 0 ..< 6))
    }

    func testFlattenZeroOrMoreStrings() {
        let parser: Consumer<String> = .flatten(.zeroOrMore("foo"))
        XCTAssertEqual(try parser.match("foofoofoo"), .token("foofoofoo", 0 ..< 9))
    }

    func testFlattenZeroOrMoreCharacters() {
        let parser: Consumer<String> = .flatten(.zeroOrMore(.character(in: "a" ... "f")))
        XCTAssertEqual(try parser.match("abcefecba"), .token("abcefecba", 0 ..< 9))
    }

    func testDiscardAnyString() {
        let parser: Consumer<String> = .discard("foo" | "bar")
        XCTAssertEqual(try parser.match("bar"), .node(nil, []))
    }

    func testDiscardAnySequence() {
        let parser: Consumer<String> = .discard(["a", "b"] | ["b", "a"])
        XCTAssertEqual(try parser.match("ab"), .node(nil, []))
    }

    func testDiscardStringSequence() {
        let parser: Consumer<String> = .discard(["foo", "bar"])
        XCTAssertEqual(try parser.match("foobar"), .node(nil, []))
    }

    func testDiscardZeroOrMoreStrings() {
        let parser: Consumer<String> = .discard(.zeroOrMore("foo"))
        XCTAssertEqual(try parser.match("foofoofoo"), .node(nil, []))
    }

    func testDiscardZeroOrMoreCharacters() {
        let parser: Consumer<String> = .discard(.zeroOrMore(.character(in: "a" ... "f")))
        XCTAssertEqual(try parser.match("abcefecba"), .node(nil, []))
    }

    func testReplaceSequence() {
        let parser: Consumer<String> = .replace([.string("foo"), .string("bar")], "baz")
        XCTAssertEqual(try parser.match("foobar"), .token("baz", 0 ..< 6))
    }

    /// MARK: Sugar

    func testStringLiteralConstructor() {
        let foo: Consumer<String> = .string("foo")
        XCTAssertEqual(foo, "foo")
    }

    func testArrayLiteralConstructor() {
        let foobar: Consumer<String> = .sequence(["foo", "bar"])
        XCTAssertEqual(foobar, ["foo", "bar"])
    }

    func testOrOperator() {
        let fooOrBar: Consumer<String> = .any(["foo", "bar"])
        XCTAssertEqual(fooOrBar, "foo" | "bar")
    }

    func testOrOperator2() {
        let fooOrBarOrBaz: Consumer<String> = .any(["foo", "bar", "baz"])
        XCTAssertEqual(fooOrBarOrBaz, "foo" | .any(["bar", "baz"]))
    }

    func testOrOperator3() {
        let fooOrBarOrBaz: Consumer<String> = .any(["foo", "bar", "baz"])
        XCTAssertEqual(fooOrBarOrBaz, .any(["foo", "bar"]) | "baz")
    }

    func testOrOperator4() {
        let fooOrBarOrBazOrQuux: Consumer<String> = .any(["foo", "bar", "baz", "quux"])
        XCTAssertEqual(fooOrBarOrBazOrQuux, .any(["foo", "bar"]) | .any(["baz", "quux"]))
    }

    func testOrOperator5() {
        let aOrB: Consumer<String> = .character(in: "a" ... "b")
        XCTAssertEqual(aOrB, .character("a") | .character("b"))
    }

    func testOrOperator6() {
        let aToE: Consumer<String> = .character(in: "abcde")
        XCTAssertEqual(aToE, .character(in: "a" ... "c") | .character(in: "b" ... "e"))
    }

    func testOrOperator7() {
        let aOrC: Consumer<String> = .anyCharacter(except: "a", "c")
        XCTAssertEqual(aOrC, .anyCharacter(except: "a", "b", "c") | .character("b"))
    }

    func testOrOperator8() {
        let aOrC: Consumer<String> = .anyCharacter(except: "a", "c")
        XCTAssertEqual(aOrC, .character("b") | .anyCharacter(except: "a", "b", "c"))
    }

    /// MARK: Composite rules

    func testOneOrMore() {
        let parser: Consumer<String> = .oneOrMore(.string("foo"))
        XCTAssertEqual(try parser.match("foo"), .node(nil, [.token("foo", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("foofoo"), .node(nil, [.token("foo", 0 ..< 3), .token("foo", 3 ..< 6)]))
        XCTAssertThrowsError(try parser.match("foobar"))
        XCTAssertThrowsError(try parser.match("barfoo"))
        XCTAssertThrowsError(try parser.match(""))
    }

    func testInterleaved() {
        let parser: Consumer<String> = .interleaved("a", ",")
        XCTAssertEqual(try parser.match("a,a"), .node(nil, [
            .token("a", 0 ..< 1), .token(",", 1 ..< 2), .token("a", 2 ..< 3),
        ]))
        XCTAssertEqual(try parser.match("a"), .node(nil, [.token("a", 0 ..< 1)]))
        XCTAssertThrowsError(try parser.match("a,"))
        XCTAssertThrowsError(try parser.match("a,a,"))
        XCTAssertThrowsError(try parser.match("a,b"))
        XCTAssertThrowsError(try parser.match("aa"))
        XCTAssertThrowsError(try parser.match(""))
    }

    /// MARK: Errors

    func testUnmatchedInput() {
        let parser: Consumer<String> = "foo"
        let input = "foo "
        XCTAssertThrowsError(try parser.match(input)) { error in
            let error = error as! Consumer<String>.Error
            switch error.kind {
            case .unexpectedToken:
                XCTAssertEqual(error.offset, 3)
            default:
                XCTFail()
            }
            XCTAssertEqual(error.description, "Unexpected token ' ' at 3")
        }
    }

    func testEmptyInput() {
        let parser: Consumer<String> = "foo"
        let input = ""
        XCTAssertThrowsError(try parser.match(input)) { error in
            let error = error as! Consumer<String>.Error
            switch error.kind {
            case .expected("foo"):
                XCTAssertEqual(error.offset, 0)
            default:
                XCTFail()
            }
            XCTAssertEqual(error.description, "Expected \"foo\" at 0")
        }
    }

    func testUnexpectedToken() {
        let parser: Consumer<String> = ["foo", "bar"]
        let input = "foofoobar"
        XCTAssertThrowsError(try parser.match(input)) { error in
            let error = error as! Consumer<String>.Error
            switch error.kind {
            case .expected("bar"):
                XCTAssertEqual(error.offset, 3)
            default:
                XCTFail()
            }
            XCTAssertEqual(error.description, "Unexpected token \"foobar\" at 3 (expected \"bar\")")
        }
    }

    func testBestMatch() {
        let parser: Consumer<String> = ["foo", "bar"] | [.oneOrMore("foo"), "baz"]
        let input = "foofoobar"
        XCTAssertThrowsError(try parser.match(input)) { error in
            let error = error as! Consumer<String>.Error
            switch error.kind {
            case .expected("baz"):
                XCTAssertEqual(error.offset, 6)
            default:
                XCTFail()
            }
            XCTAssertEqual(error.description, "Unexpected token \"bar\" at 6 (expected \"baz\")")
        }
    }

    /// MARK: Consumer description

    func testLabelAndReferenceDescription() {
        XCTAssertEqual(Consumer<String>.label("foo", "bar").description, "foo")
        XCTAssertEqual(Consumer<String>.reference("foo").description, "foo")
    }

    func testStringDescription() {
        XCTAssertEqual(Consumer<String>.string("foo").description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.string("\0").description, "'\\0'")
        XCTAssertEqual(Consumer<String>.string("\t").description, "'\\t'")
        XCTAssertEqual(Consumer<String>.string("\r").description, "'\\r'")
        XCTAssertEqual(Consumer<String>.string("\n").description, "'\\n'")
        XCTAssertEqual(Consumer<String>.string("\r\n").description, "\"\\r\\n\"")
        XCTAssertEqual(Consumer<String>.string("\"").description, "'\\\"'")
        XCTAssertEqual(Consumer<String>.string("\'").description, "'\\''")
        XCTAssertEqual(Consumer<String>.string("ö").description, "U+00F6")
        XCTAssertEqual(Consumer<String>.string("Zöe").description, "\"Z\\u{F6}e\"")
        XCTAssertEqual(Consumer<String>.string("👍").description, "U+1F44D")
        XCTAssertEqual(Consumer<String>.string("Thanks 👍").description, "\"Thanks \\u{1F44D}\"")
    }

    func testCharacterDescription() {
        XCTAssertEqual(Consumer<String>.character("!").description, "'!'")
        XCTAssertEqual(Consumer<String>.character(in: "A" ... "F").description, "'A' – 'F'")
        XCTAssertEqual(Consumer<String>
            .character(in: UnicodeScalar(257)! ... UnicodeScalar(999)!).description, "U+0101 – U+03E7")
        XCTAssertEqual(Consumer<String>.character(in: "👍" ... "👍").description, "U+1F44D")
        XCTAssertEqual(Consumer<String>.character(in: "12").description, "'1' or '2'")
        XCTAssertEqual(Consumer<String>.character(in: "1356").description, "'1', '3', '5' or '6'")
        XCTAssertEqual(Consumer<String>.character(in: "").description, "nothing")
        XCTAssertEqual(Consumer<String>.anyCharacter(except: "\"").description, "any character except '\\\"'")
        XCTAssertEqual(Consumer<String>.anyCharacter().description, "any character")
    }

    func testAnyDescription() {
        XCTAssertEqual(Consumer<String>.any(["foo", "bar"]).description, "\"foo\" or \"bar\"")
        XCTAssertEqual(Consumer<String>.any(["foo", "foo"]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.any(["a", "b", "c"]).description, "'a', 'b' or 'c'")
        XCTAssertEqual(Consumer<String>.any(["a", "b", "a"]).description, "'a' or 'b'")
        XCTAssertEqual(Consumer<String>.any(["a", "a", "b"]).description, "'a' or 'b'")
        XCTAssertEqual(Consumer<String>.any([.optional("a"), "b"]).description, "'a' or 'b'")
        XCTAssertEqual(Consumer<String>.any([.optional("foo"), "bar"]).description, "\"foo\" or \"bar\"")
        XCTAssertEqual(Consumer<String>.any(["foo"]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.any([]).description, "nothing")
    }

    func testSequenceDescription() {
        XCTAssertEqual(Consumer<String>.sequence(["foo", "bar"]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.sequence(["a" | "b"]).description, "'a' or 'b'")
        XCTAssertEqual(Consumer<String>.sequence([.optional("a"), "b"]).description, "'a' or 'b'")
        XCTAssertEqual(Consumer<String>.sequence(["foo"]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.sequence([.reference("foo")]).description, "foo")
        XCTAssertEqual(Consumer<String>.sequence([.label("foo", "bar")]).description, "foo")
        XCTAssertEqual(Consumer<String>.sequence([.sequence(["foo"])]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.sequence([[.optional("foo"), "b"]]).description, "\"foo\" or 'b'")
        XCTAssertEqual(Consumer<String>.sequence([[.optional("foo"), "foo"]]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.sequence([.flatten("foo")]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.sequence([.discard("foo")]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.sequence([.replace("foo", "bar")]).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.sequence([]).description, "nothing")
    }

    func testOptionalAndZeroOrMore() {
        XCTAssertEqual(Consumer<String>.optional("foo").description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.zeroOrMore("foo").description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.zeroOrMore(.optional("foo")).description, "\"foo\"")
    }

    func testFlattenDiscardReplace() {
        XCTAssertEqual(Consumer<String>.flatten("foo").description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.discard("foo").description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.replace("foo", "bar").description, "\"foo\"")
    }

    /// MARK: Match descriptions

    func testTokenDescription() {
        XCTAssertEqual(Consumer<String>.Match.token("foo", nil).description, "\"foo\"")
        XCTAssertEqual(Consumer<String>.Match.token("a", 1 ..< 3).description, "'a'")
    }

    func testNodeDescription() {
        XCTAssertEqual(Consumer<String>.Match.node(nil, [.token("foo", nil)]).description, "(\"foo\")")
        XCTAssertEqual(Consumer<String>.Match.node(nil, []).description, "()")
        XCTAssertEqual(Consumer<String>.Match.node(nil, [
            .token("foo", nil), .token("bar", nil),
        ]).description, "(\n    \"foo\"\n    \"bar\"\n)")
        XCTAssertEqual(Consumer<String>.Match.node("foo", [.token("bar", nil)]).description, "(foo \"bar\")")
        XCTAssertEqual(Consumer<String>.Match.node("foo", []).description, "(foo)")
        XCTAssertEqual(Consumer<String>.Match.node("foo", [
            .token("bar", nil), .token("baz", nil),
        ]).description, "(foo\n    \"bar\"\n    \"baz\"\n)")
    }

    func testNestedNodeDescription() {
        XCTAssertEqual(Consumer<String>.Match.node("foo", [
            .node("bar", [.token("baz", nil), .token("quux", nil)]),
        ]).description, """
        (foo (bar
            "baz"
            "quux"
        ))
        """)
        XCTAssertEqual(Consumer<String>.Match.node("foo", [
            .node("bar", [.token("baz", nil)]),
            .node("quux", []),
        ]).description, """
        (foo
            (bar "baz")
            (quux)
        )
        """)
    }

    /// MARK: Edge cases with optionals

    func testZeroOrMoreOptionals() {
        let parser: Consumer<String> = .zeroOrMore([.optional("foo")])
        XCTAssertEqual(try parser.match(""), .node(nil, []))
        XCTAssertEqual(try parser.match("foo"), .node(nil, [.token("foo", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("foofoo"), .node(nil, [
            .token("foo", 0 ..< 3), .token("foo", 3 ..< 6),
        ]))
    }

    func testZeroOrMoreZeroOrMores() {
        let parser: Consumer<String> = .zeroOrMore([.zeroOrMore("foo")])
        XCTAssertEqual(try parser.match(""), .node(nil, []))
        XCTAssertEqual(try parser.match("foo"), .node(nil, [.token("foo", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("foofoo"), .node(nil, [
            .token("foo", 0 ..< 3), .token("foo", 3 ..< 6),
        ]))
    }

    func testZeroOrMoreAnyOptionals() {
        let parser: Consumer<String> = [.zeroOrMore(.optional("foo") | .optional("bar"))]
        XCTAssertEqual(try parser.match(""), .node(nil, []))
        XCTAssertEqual(try parser.match("foo"), .node(nil, [.token("foo", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("bar"), .node(nil, [.token("bar", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("barfoo"), .node(nil, [
            .token("bar", 0 ..< 3), .token("foo", 3 ..< 6),
        ]))
    }

    func testZeroOrMoreSequencesOfOptionals() {
        let parser: Consumer<String> = [.zeroOrMore([.optional("foo"), .optional("bar")])]
        XCTAssertEqual(try parser.match(""), .node(nil, []))
        XCTAssertEqual(try parser.match("foo"), .node(nil, [.token("foo", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("bar"), .node(nil, [.token("bar", 0 ..< 3)]))
        XCTAssertEqual(try parser.match("barfoo"), .node(nil, [
            .token("bar", 0 ..< 3), .token("foo", 3 ..< 6),
        ]))
    }
}
