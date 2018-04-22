## [0.3.4](https://github.com/nicklockwood/Consumer/releases/tag/0.3.4) (2018-04-22)

- Fixed deprecation warning in Swift 4.1

## [0.3.3](https://github.com/nicklockwood/Consumer/releases/tag/0.3.3) (2018-03-28)

- Made `Match.transform()` function public (it was inadvertently left with module scope)
- Improved performance when parsing `oneOrMore(charset)` patterns
- Fixed Swift Package Manager integration

## [0.3.2](https://github.com/nicklockwood/Consumer/releases/tag/0.3.2) (2018-03-19)

- Added `not()` consumer, required for matching patterns like C-style /* ... */ comments
- Added `ignore()` constructor for conveniently ignoring white space or comments between tokens
- Improved description for `charset` consumer

## [0.3.1](https://github.com/nicklockwood/Consumer/releases/tag/0.3.1) (2018-03-15)

- Added `isOptional` property for checking if a given consumer will match empty input
- Implemented more consistent rules for optionals inside `any`, `sequence` and `oneOrMore` clauses
- Fixed slow compilation (caused by a Swift compiler bug relating to switch/case exhaustiveness)

## [0.3.0](https://github.com/nicklockwood/Consumer/releases/tag/0.3.0) (2018-03-14)

- Added new `Location` type that provides line and column information for tokens
- Fixed expected token description reported when matching fails
- Removed deprecated methods

## [0.2.4](https://github.com/nicklockwood/Consumer/releases/tag/0.2.4) (2018-03-11)

- Fixed bug where error was reported at the wrong source offset 
- Fixed bug where error description contained duplicate expected consumers
- Replaced `zeroOrMore` with `oneOrMore` as a base type (doesn't affect the public API)

## [0.2.3](https://github.com/nicklockwood/Consumer/releases/tag/0.2.3) (2018-03-09)

- Improved performance and error messaging when using Foundation's `CharacterSet` for character matching

## [0.2.2](https://github.com/nicklockwood/Consumer/releases/tag/0.2.2) (2018-03-08)

- Added support for matching Foundation `CharacterSet`s, along with several new character-based convenience methods (see README for details)
- Deprecated the old character-matching methods in favor of `character(in: ...)` variants
- Added ~2x performance improvement when using the new character consumers

## [0.2.1](https://github.com/nicklockwood/Consumer/releases/tag/0.2.1) (2018-03-06)

- Added fast-paths when using `flatten`, `replace` and `discard` transforms
- Improved performance of JSON example, and added performance tips section to README
- Fixed infinite loop bug with nested optionals inside zeroOrMore consumer
- Added handwritten JSON parser for benchmark comparison

## [0.2.0](https://github.com/nicklockwood/Consumer/releases/tag/0.2.0) (2018-03-05)

- Fixed a bug where the character offset reported in an error message was wrong in some cases
- Transform function values argument is now an array. This solves a consistency issue where an `.optional(.string(...))` consumer would return a string if matched but an empty array if not matched

## [0.1.1](https://github.com/nicklockwood/Consumer/releases/tag/0.1.1) (2018-03-03)

- Significantly improved parsing performance

## [0.1.0](https://github.com/nicklockwood/Consumer/releases/tag/0.1.0) (2018-03-01)

- First release
