# Loop Fusion

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

Iterate efficiently over a variadic number of containers.

  * The loop structure is generated inline at compile-time.
  * There are no temporary allocation.

## Status

The containers can be seq of any type. In the future this will be generalized to `openarray` or even an `Iterable` concept.

## Usage

```Nim
import loopfusion

block: # Simple
  let a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]

  forEach x in a, y in b, z in c:
    echo (x + y) * z

  # 120
  # 140
  # 160

block: # With index
  let a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]
  var d: seq[int] = @[]

  forEach i, x in a, y in b, z in c:
    d.add i + x + y + z

  doAssert d == @[22, 25, 28]

block: # With mutation
  var a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]

  forEach x in var a, y in b, z in c:
    x += y * z

  doAssert a == @[111, 122, 133]

block: # With mutation, index and multiple statements
  var a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]

  forEach i, x in var a, y in b, z in c:
    let tmp = i * (y - z)
    x += tmp

  doAssert a == @[1, 4, 9]

block: # With iteration on seq of different types
  let a = @[1, 2, 3]
  let b = @[false, true, true]

  forEach integer in a, boolean in b:
    if boolean:
      echo integer

block: # With an expression
  let a = @[1, 2, 3]
  let b = @[4, 5, 6]


  let c = forEach(x in a, y in b):
    x + y

  doAssert c == @[5, 7, 9]
```

Note at the moment the expression must return a value for each element.

## Name

The library name "Loop fusion" might be a bit confusing since there is no loop to fuse at start.
In spirit however, it is similar while "real" loop fusion merge multiple loops over multiple sequences.

It's also marketable =) (check loop fusion + \<insert favorite language\>)

## The future

### Pending upstream

For expression would be a great boon and would allow something similar to:

```Nim
let As = @[1, 2, 3]
let Bs = @[10, 10, 10]

let c = forEach a in As, b in Bs:
          (a * b) + b

echo c # @[11, 22, 33]
```

### Experimental features

In the experimental folder you will find an `elementwise` macro that avoids the need to specify an index name.

```Nim
import loopfusion/experimental

let a = @[1, 2, 3]
let b = @[4, 5, 6]
let c = @[10, 10, 10]

let d = @[100, 200, 300]

elementwise(d,a,b,c):
  let z = b + c
  echo d + a * z

# 114
# 230
# 348
```

However this might makes the following quite brittle:
```Nim
elementwise:
  let z = b[1] + c[2] # How to tell that b[1] and c[2] are invariants? This is "untyped" when the macro operates.
  echo d + a * z
```
