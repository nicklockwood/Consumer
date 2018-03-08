[![Travis](https://img.shields.io/travis/nicklockwood/Consumer.svg)](https://travis-ci.org/nicklockwood/Consumer)
[![Coveralls](https://coveralls.io/repos/github/nicklockwood/Consumer/badge.svg)](https://coveralls.io/github/nicklockwood/Consumer)
[![Platform](https://img.shields.io/cocoapods/p/Consumer.svg?style=flat)](http://cocoadocs.org/docsets/Consumer)
[![Swift 3.2](https://img.shields.io/badge/swift-3.2-orange.svg?style=flat)](https://developer.apple.com/swift)
[![Swift 4.0](https://img.shields.io/badge/swift-4.0-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)
[![Twitter](https://img.shields.io/badge/twitter-@nicklockwood-blue.svg)](http://twitter.com/nicklockwood)

- [Introduction](#introduction)
	- [What?](#what)
	- [Why?](#why)
	- [How?](#how)
- [Usage](#usage)
    - [Installation](#installation)
    - [Parsing](#parsing)
    - [Transforming](#transforming)
    - [Common Transforms](#common-transforms)
    - [Typed Labels](#typed-labels)
    - [Forward References](#forward-references)
    - [Syntax Sugar](#syntax-sugar)
- [Performance](#performance)
    - [Backtracking](#backtracking)
    - [Character Sequences](#character-sequences)
    - [Flatten and Discard](#flatten-and-discard)
- [Example Projects](#example-projects)
    - [JSON](#json)
    - [REPL](#repl)


# Introduction

## What?

Consumer is a library for Mac and iOS for parsing structured text such as a configuration file, or a programming language source file.

The primary interface is the `Consumer` type, which is used to programmatically build up a parsing grammar.

Using that grammar, you can then parse String input into an AST (Abstract Syntax Tree), which can then be transformed into application-specific data

**Note: Consumer is at a very early stage of development. Performance is not great, and breaking changes are likely. It is not recommended that you use it in production at this time.**

## Why?

There are many situations where it is useful to be able to parse structured data. Most popular file formats have some kind of parser, typically either written by hand or by using code generation. 

Writing a parser is a time-consuming and error-prone process. Many tools exist in the C world for generating parsers, but relatively few such tools exist for Swift.

Swift's strong typing and sophisticated enum types make it well-suited for creating parsers, and Consumer takes advantage of these features.

## How?

Consumer uses an approach called *recursive descent* to parse input. Each `Consumer` instance consists of a tree of sub-consumers, with the leaves of the tree matching individual strings or characters in the input.

You build up a consumer by starting with simple rules that match individual words or values (known as "tokens") in your language or file format. You then compose these into more complex rules that match sequences of tokens, and so on until you have a single consumer that describes an entire document in the language you are trying to parse.


# Usage

## Installation

The `Consumer` type and its dependencies are encapsulated in a single file, and everything public is prefixed or name-spaced, so you can simply drag `Consumer.swift` into your project to use it.

If you prefer, there's a framework for Mac and iOS that you can import which includes the `Consumer` type. You can install this manually, or by using CocoaPods, Carthage, or Swift Package Manager.

To install Consumer using CocoaPods, add the following to your Podfile:

```ruby
pod 'Consumer', '~> 0.2'
```

To install using Carthage, add this to your Cartfile:

```
github "nicklockwood/Consumer" ~> 0.2
```

## Parsing

The `Consumer` type is an enum, so you can create a consumer by assigning one of its possible values to a variable. For example, here is a consumer that matches the string "foo":

```swift
let foo: Consumer<String> = .string("foo")
```

To parse a string with this consumer, call the `match()` function:

```swift
do {
    let match = try foo.match("foo")
    print(match) // Prints the AST
} catch {
    print(error)
}
```

In this simple example above, the match will always succeed. If tested against arbitrary input, the match will potentially fail, in which case an Error will be thrown. The Error will be of type `Consumer.Error`, which includes information about the error type and the location in the input string where it occurred.

The example above is not very useful - there are much simpler ways to detect string equality! Let's try a slightly more advanced example. The following consumer matches an unsigned integer:

```swift
let integer: Consumer<String> = .oneOrMore(.character(in: .decimalDigits))
```

The top-level consumer in this case is of type `oneOrMore`, meaning that it matches one or more instances of the nested `.character(in: .decimalDigits)` consumer. In other words, it will match any sequence of decimal digits.

There's a slight problem with this implementation though: An arbitrary sequence of digits might include leading zeros, e.g. `01234`, which could be mistaken for an octal number in some programming languages, or even just be treated as a syntax error. How can we modify the `integer` consumer to reject leading zeros?

We need to treat the first character differently from the subsequent ones, which means we need two different parsing rules to be applied in *sequence*. For that, we use a `sequence` consumer:

```swift
let integer: Consumer<String> = .sequence([
    .character(in: "1" ... "9"),
    .zeroOrMore(.character(in: .decimalDigits)),
])
```

So instead of `oneOrMore` digits in the range 0 - 9, we're now looking for a single digit in the range 1 - 9, followed by `zeroOrMore` digits in the range 0 - 9. That means that a zero preceding a nonzero digit will not be matched.

```swift
do {
    _ = try integer.match("0123")
} else {
    print(error) // Unexpected token "0123" at 0
}
```

We've introduced another bug though - Although leading zeros are correctly rejected, "0" on its own will now also be rejected since it doesn't start with 1 - 9. We need to accept *either* zero on its own, *or* the sequence we just defined. For that, we can use `any`:

```swift
let integer: Consumer<String> = .any([
    .character("0"),
    .sequence([
        .character(in: "1" ... "9"),
        .zeroOrMore(.character(in: .decimalDigits)),
    ]),
])
```

That will do what we want, but it's quite a bit more complex. To make it more readable, we could break it up into separate variables:

```swift
let zero: Consumer<String> = .character("0")
let oneToNine: Consumer<String> = .character(in: "1" ... "9")
let zeroToNine: Consumer<String> = .character(in: .decimalDigits)

let nonzeroInteger: Consumer<String> = .sequence([
    .oneToNine, .zeroOrMore(zeroToNine),
])

let integer: Consumer<String> = .any([
    zero, nonzeroInteger,
])
```

We can then further extend this with extra rules, e.g.

```swift
let sign = .any(["+", "-"])

let signedInteger: Consumer<String> = .sequence([
    .optional(sign), integer,
])
```

## Transforming

In the previous section we wrote a consumer that can match an integer number. But what do we get when we apply that to some input? Here is the matching code:

```swift
let match = try integer.match("1234")
print(match)
```

And here is the output:

```
(
    '1'
    '2'
    '3'
    '4'
)
```

That's ... odd. You were probably hoping for a String containing "1234", or at least something a bit simpler to work with.

If we dig in a bit deeper and look at the structure of the `Match` value returned, we'll find it's something like this (omitting namespaces and other metadata for clarity):

```swift
Match.node(nil, [
    Match.token("1", 0 ..< 1),
    Match.token("2", 1 ..< 2),
    Match.token("3", 2 ..< 3),
    Match.token("4", 3 ..< 4),
])
```

Because each digit in the number was matched individually, the result has been returned as an array of tokens, rather than a single token representing the entire number. This level of detail is potentially useful for some applications, but we don't need it right now - we just want to get the value. To do that, we need to *transform* the output.

The `Match` type has a method called `transform()` for doing exactly that. The `transform()` method takes a closure argument of type `Transform`, which has the signature `(_ name: Label, _ values: [Any]) throws -> Any?`. The closure is applied recursively to all matched values in order to convert them to whatever form your application needs.

Unlike parsing, which is done from the top down, transforming is done from the bottom up. That means that the child nodes of each `Match` will be transformed before their parents, so that all the values passed to the transform closure should have already been converted to the expected types.

So the transform function takes an array of values and collapses them into a single value (or nil) - pretty straightforward - but you're probably wondering about the `Label` argument. If you look at the definition of the `Consumer` type, you'll notice that it also takes a generic argument of type `Label`. In the examples so far we've been passing `String` as the label type, but we've not actually used it yet.

The `Label` type is used in conjunction with the `label` consumer. This allows you to assign a name to a given consumer rule, which can be used to refer to it later. Since you can store consumers in variables and refer to them that way, it's not immediately obvious why this is useful, but it has two purposes:

The first purpose is to allow [forward references](#forward-references), which are explained below.

The second purpose is for use when transforming, to identify the type of node to be transformed. Labels assigned to consumer rules are preserved in the `Match` node after parsing, making it possible to identify which rule was matched to create a particular type of value. Matched values that are not labelled cannot be individually transformed, they will instead be be passed as the values for the first labelled parent node.

So, to transform the integer result, we must first give it a label, by using the `label` consumer type:

```swift
let integer: Consumer<String> = .label("integer", .any([
    .character("0"),
    .sequence([
        .character(in: "1" ... "9"),
        .zeroOrMore(.character(in: .decimalDigits)),
    ]),
]))
```

We can then transform the match using the following code:

```swift
let result = try integer.match("1234").transform { label, values in
    switch label {
    case "integer":
        return (values as! [String]).joined()
    default:
        preconditionFailure("unhandled rule: \(name)")
    }
}
print(result ?? "")
```

We know that the `integer` consumer will always return an array of string tokens, so we can safely use `as!` in this case to cast `values` to `[String]`. This is not especially elegant, but its the nature of dealing with dynamic data in Swift. Safety purists may prefer to use `as?` and throw an `Error` or return `nil` if the value is not a `[String]`, but that situation could only arise in the event of a programming error - no input data matched by the `integer` consumer we've defined above will ever return anything else.

With the addition of this function, the array of character tokens is transformed into a single string value. The printed result is now simply "1234". That's much better, but it's still a `String`, and we may well want it to be an actual `Int` if we're going to use the value. Since the `transform` function returns `Any?`, we can return any type we want, so let's modify it to return an `Int` instead:

```swift
switch label {
case "integer":
    let string = (values as! [String]).joined()
    guard let int = Int(string) else {
        throw MyError(message: "Invalid integer literal '\(string)'")
    }
    return int
default:
    preconditionFailure("unhandled rule: \(name)")
}
```

The `Int(_ string: String)` initializer returns an `Optional` in case the argument cannot be converted to an `Int`. Since we've already pre-determined that the string only contains digits, you might think we could safely force unwrap this, but it is still possible for the initializer to fail - the matched integer might have too many digits to fit into 64 bits, for example.

We could just return the result of `Int(string)` directly, since the return type for the transform function is `Any?`, but this would be a mistake because that would silently omit the number from the output if the conversion failed, and we actually want to treat it as an error instead.

We've used an imaginary error type called `MyError` here, but you can use whatever type you like. Consumer will wrap the error you throw in a `Consumer.Error` before returning it, which will annotate it with the source input offset and other useful metadata preserved from the parsing process.

## Common Transforms

Certain types of transform are very common. In addition to the Array -> String conversion we've just done, other examples include discarding a value (equivalent to returning `nil` from the transform function), or substituting a given string for a different one (e.g. replace "\n" with a newline character, or vice-versa).

For these common operations, rather than applying a label to the consumer and having to write a transform function, you can use one of the built-in consumer transforms: 

* `flatten` - flattens a node tree into a single string token
* `discard` - removes a matched string token or node tree from the results
* `replace` - replaces a matched node tree or string token with a different string token

Note that these transforms are applied during the parsing phase, before the `Match` is returned or the regular `transform()` function can be applied.

Using the `flatten` consumer, we can simplify our integer transform a bit:

```swift
let integer: Consumer<String> = .label("integer", .flatten(.any([
    .character("0"),
    .sequence([
        .character(in: "1" ... "9"),
        .zeroOrMore(.character(in: .decimalDigits)),
    ]),
])))

let result = try integer.match("1234").transform { label, values in
    switch label {
    case "integer":
        let string = values[0] as! String // matched value is now always a string
        guard let int = Int(string) else {
            throw MyError(message: "Invalid integer literal '\(string)'")
        }
        return int
    default:
        preconditionFailure("unhandled rule: \(name)")
    }
}
```

## Typed Labels

Besides the need for force-unwrapping, another inelegance in our transform function is the need for the `default:` clause in the `switch` statement. Swift is trying to be helpful here by insisting that we handle all possible label values, but we *know* that "integer" is the only possible label in this code, so the `default:` is redundant.

Fortunately, Swift's type system can help here. Remember that the label value is not actually a `String` but a generic type `Label`. This allows use to use any type we want for the label (provided it conforms to `Hashable`), and a really good approach is to create an `enum` for the `Label` type:

```swift
enum MyLabel: String {
    case integer
}
```

If we now change our code to use this `MyLabel` enum instead of `String`, we avoid error-prone copying and pasting of string literals and we eliminate the need for the `default:` clause in the transform function, since Swift can now determine statically that `integer` is the only possible value. The other nice benefit is that if we add other label types in future, the compiler will warn us if we forget to implement transforms for them.

The complete, updated code for the integer consumer is shown below:

```swift
enum MyLabel: String {
    case integer
}

let integer: Consumer<MyLabel> = .label(.integer, .flatten(.any([
    .character("0"),
    .sequence([
        .character(in: "1" ... "9"),
        .zeroOrMore(.character(in: .decimalDigits)),
    ]),
])))

enum MyError: Error {
    let message: String
}

let result = try integer.match("1234").transform { label, values in
    switch label {
    case .integer:
        let string = values[0] as! String
        guard let int = Int(string) else {
            throw MyError(message: "Invalid integer literal '\(string)'")
        }
        return int
    }
}
print(result ?? "")
```

## Forward References

More complex parsing grammars (e.g. for a programming language or a structured data file) may require circular references between rules. For example, here is an abridged version of the grammar for parsing JSON:

```swift
let null: Consumer<String> = .string("null")
let bool: Consumer<String> = ...
let number: Consumer<String> = ...
let string: Consumer<String> = ...
let object: Consumer<String> = ...

let array: Consumer<String> = .sequence([
    .string("["),
    .optional(.interleaved(json, ","))
    .string("]"),
])

let json: Consumer<String> = .any([null, bool, number, string, object, array])
```

The `array` consumer contains a comma-delimited sequence of `json` values, and the `json` consumer can match any other type, including `array` itself.

You see the problem? The `array` consumer references the `json` consumer before it has been declared. This is known as a *forward reference*. You might think we can solve this by predeclaring the `json` variable before we assign its value, but this won't work - `Consumer` is a value type, so every reference to it is actually a copy - it needs to be defined up front.

In order to implement this, we need to make use of the `label` and `reference` features. First, we must give the `json` consumer a label so that it can be referenced before it is declared:

```swift
let json: Consumer<String> = .label("json", .any([null, bool, number, string, object, array]))
```

Then we replace `json` inside the `array` consumer with `.reference("json")`:

```swift
let array: Consumer<String> = .sequence([
    .string("["),
    .optional(.interleaved(.reference("json"), ","))
    .string("]"),
])
```

**Note:** You must be careful when using references like this, not just to ensure that the named consumer actually exists, but that it is included in a non-reference form somewhere in your root consumer (the one which you actually try to match against the input). In this case, `json` *is* the root consumer, so we know it exists, but what if we had defined the reference the other way around:

```swift
let json: Consumer<String> = .any([null, bool, number, string, object, .reference("array")])

let array: Consumer<String> = .label("array", .sequence([
    .string("["),
    .optional(.interleaved(json, ","))
    .string("]"),
]))
```

So now we've switched things up so that `json` is defined first, and has a forward reference to `array`. It seems like this should work, but it won't. The problem is that when we go to match `json` against an input string, there's no copy of the actual `array` consumer anywhere in the `json` consumer. It's referenced by name only.

You can avoid this problem if you ensure that references only point from child nodes to their parents, and that parent consumers reference their children directly, rather than by name.

## Syntax Sugar

Consumer deliberately doesn't go overboard with custom operators because it can make code that is inscrutable to other Swift developers, however there are a few syntax extensions that can help to make your parser code a bit more readable:

The `Consumer` type conforms to `ExpressibleByStringLiteral` as shorthand for the `.string()` case, which means that instead of writing:

```swift
let foo: Consumer<String> = .string("foo")
let foobar: Consumer<String> = .sequence([.string("foo"), .string("bar")])
```

You can actually just write:

```swift
let foo: Consumer<String> = "foo"
let foobar: Consumer<String> = .sequence(["foo", "bar"])
```

Additionally, `Consumer` conforms to `ExpressibleByArrayLiteral` as a shorthand for `.sequence()`, so instead of:

```swift
let foobar: Consumer<String> = .sequence(["foo", "bar"])
```

You can just write:

```swift
let foobar: Consumer<String> = ["foo", "bar"]
```

The OR operator `|` is also overloaded for `Consumer` as an alternative to using `.any()`, so instead of:

```swift
let fooOrbar: Consumer<String> = .any(["foo", "bar"])
```

You can write:

```swift
let fooOrbar: Consumer<String> = "foo" | "bar"
```

Be careful when using the `|` operator for very complex expressions however, as it can cause Swift's compile time to go up exponentially due to the complexity of type inference. It's best to only use `|` for a small number of cases. If it's more than 4 or 5, or if it's deeply nested inside a complex expression, you should probably use `any()` instead.


# Performance

The performance of a Consumer parser can be greatly affected by the way that your rules are structured. This section includes some tips for getting the best possible parsing speed.

**Note:** As with any performance tuning, it's important that you *measure* the performance of your parser before and after making changes, otherwise you may waste time optimizing something that's already fast enough, or even inadvertently make it slower.

## Backtracking

The best way to get good parsing performance from your Consumer grammar is to try to avoid *backtracking*.

Backtracking is when the parser has to throw away partially matched results and parse them again. It occurs when multiple consumers in a given `any` group begin with the same token or sequence of tokens.

For example, here is an example of an inefficient pattern:

```swift
let foobarOrFoobaz: Consumer<String> = .any([
    .sequence(["foo", "bar"]),
    .sequence(["foo", "baz"]),
])
```

When the parser encounters the input "foobaz", it will first match "foo", then try to match "bar". When that fails it will backtrack right back to the beginning and try the second sequence of "foo" followed by "baz". This will make parsing slower than it needs to be.

We could instead rewrite this as:

```swift
let foobarOrFoobaz: Consumer<String> = .sequence([
    "foo", .any(["bar", "baz"])
])
```

This consumer matches exactly the same input as the previous one, but after successfully matching "foo", if it fails to match "bar" it will try "baz" immediately, instead of going back and matching "foo" again. We have eliminated the backtracking.

## Character Sequences

The following consumer example matches a quoted string literal containing escaped quotes. It matches a zero or More instances of either an escaped quote `\"` or any other character besides `"`.

```swift
let stringChars = CharacterSet(charactersIn: "\0" ... "\u{10FFFF}").subtracting(CharacterSet(charactersIn: "\"")) // Any character except "
let string: Consumer<String> = .flatten(.sequence([
    .discard("\""),
    .zeroOrMore(.any([
        .replace("\\\"", "\""), // Escaped "
        .character(in: stringChars),
    ])),
    .discard("\""),
]))
```

The above implementation works as expected, but it is not as efficient as it could be. For each character encountered, it must first check for an escaped quote, and then check if it's any other character. That's quite an expensive check to perform, and it can't (currently) be optimized by the Consumer framework.

Consumer has optimized code paths for matching `.zeroOrMore(.character(...))` or `.oneOrMore(.character(...))` rules, and we can rewrite the string consumer to take advantage of this optimization as follows:

```swift
let stringChars = CharacterSet(charactersIn: "\0" ... "\u{10FFFF}").subtracting(CharacterSet(charactersIn: "\"\\")) // Any character except " and \
let string: Consumer<String> = .flatten(.sequence([
    .discard("\""),
    .zeroOrMore(.any([
        .replace("\\\"", "\""), // Escaped "
        .oneOrMore(.character(in: stringChars)),
    ])),
    .discard("\""),
]))
```

Since most characters in a typical string are not \ or ", this will run much faster because it can efficiently consume a long run of non-escape characters between each escape sequence.

## Flatten and Discard

We mentioned the `flatten` and `discard` transforms in the [Common Transforms](#common-transforms) section above, as a convenient way to omit redundant information from the parsing results prior to applying a custom transform.

But using "flatten" and "discard" can also improve performance, by simplifying the parsing process, and avoiding the need to gather a propagate unnecessary information like source offsets.

If you intend to eventually flatten a given node of your matched results, it's  much better to do this within the consumer itself by using the `flatten` rule than by using `joined()` in your transform function. The only time when you won't be able to do this is if some of the child consumers need custom transforms to be applied, because by flattening the node tree you remove the labels that are needed to reference the node in your transform.

Similarly, for unneeded match results (e.g. commas, brackets and other punctuation that isn't needed after initial parsing) you should always use `discard` to remove the node or token from the match results before applying a transform.

**Note:** Transform rules are applied hierarchically, so if a parent consumer already has `flatten` applied, there is no further performance benefit to be gained from applying it individually to the children of that consumer.


# Example Projects

Consumer includes a number of example projects to demonstrate the framework:

## JSON

The JSON example project implements a [JSON](https://json.org) parser, along with a transform function to convert it into Swift data.

## REPL

The REPL (Read Evaluate Print Loop) example is a Mac command-line tool for evaluating expressions. The REPL can handle numbers, booleans and string values, but currently only supports basic math operations.

Each line you type into the REPL is evaluated independently and the result is printed in the console. To share values between expressions, you can define variables using an identifier name followed by `=` and then an expression, e.g:

```
foo = (5 + 6) + 7
```

The named variable ("foo", in this case) is then available to use in subsequent expressions.

This example demonstrates a number of advanced techniques, such as mutually recursive consumer rules, and operator precedence.
