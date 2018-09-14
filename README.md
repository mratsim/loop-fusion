# Loop Fusion

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

Iterate efficiently over a variadic number of containers.

  * The loop structure is generated inline at compile-time.
  * There are no temporary allocation.

## Status

The containers can be any number of seq, arrays or openarray of any subtype.
You can enumerate on a loop index of your choice, it must be the first parameter.

## Usage

```Nim
import loopfusion

block: # Simple
  let a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]

  forZip x in a, y in b, z in c:
    echo (x + y) * z

  # 120
  # 140
  # 160

block: # With index
  let a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]
  var d: seq[int] = @[]

  forZip i, x in a, y in b, z in c:
    d.add i + x + y + z

  doAssert d == @[22, 25, 28]

block: # With mutation
  var a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]

  forZip x in var a, y in b, z in c:
    x += y * z

  doAssert a == @[111, 122, 133]

block: # With mutation, index and multiple statements
  var a = @[1, 2, 3]
  let b = @[11, 12, 13]
  let c = @[10, 10, 10]

  forZip i, x in var a, y in b, z in c:
    let tmp = i * (y - z)
    x += tmp

  doAssert a == @[1, 4, 9]

block: # With iteration on seq of different types
  let a = @[1, 2, 3]
  let b = @[false, true, true]

  forZip integer in a, boolean in b:
    if boolean:
      echo integer

block: # With an expression
  let a = @[1, 2, 3]
  let b = @[4, 5, 6]


  let c = forZip(x in a, y in b):
    x + y

  doAssert c == @[5, 7, 9]


block: # With arrays + seq, mutation, index and multiple statements
  var a = [1, 2, 3]
  let b = [11, 12, 13]
  let c = @[10, 10, 10]

  forZip i, x in var a, y in b, z in c:
    let tmp = i * (y - z)
    x += tmp

  doAssert a == [1, 4, 9]

```

Expressions must return value of the same types, i.e. you can't return `void`/no value at some iterations and a concrete value at other iterations.

Due to parsing limitations, expressions `let foo = forZip(...)` require parenthesis.

## Name

The library name "Loop fusion" might be a bit confusing since there is no loop to fuse at start.
In spirit however, it is similar while "real" loop fusion merge multiple loops over multiple sequences.

It's also marketable =) (check loop fusion + \<insert favorite language\>)

## Implementation details

Many would probably be curious why I first generate a zip iterator then a for-loop instead of for-looping directly.

This is because it started as a variadic zip proof of concept for [Arraymancer](https://github.com/mratsim/Arraymancer) for which I need an iterator to abstract iteration details, especially in the context of multithreading.

There should be no performance cost as Nim inlines iterators as if the loop was written manually.
