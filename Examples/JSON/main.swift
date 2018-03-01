//
//  main.swift
//  JSON
//
//  Created by Nick Lockwood on 01/03/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

import Foundation

// Example input
let input = """
{
    "foo": true,
    "bar": [0, 1, 2.0, -0.7, null, "hello world"],
    "baz": {
        "quux": null
    }
}
"""

do {
    let match = try json.match(input)
    let output = try match.transform(jsonTransform)
    print(output!)
} catch {
    print(error)
}
