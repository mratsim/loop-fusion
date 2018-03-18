# Loop Fusion

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

Iterate efficiently over a variadic number of containers.

  * The loop structure is generated inline at compile-time.
  * There are no temporary allocation.

### Status

The containers can be seq of any type. In the future this will be generalized to `openarray` or even an `Iterable` concept.

Currently `forEach` and `forEachIndexed` are implemented. A `loopfusion` macro is coming soon™.

Note: at the moment all the seqs must contain the same element type.

### Usage

```Nim
import loopfusion

let a = @[1, 2, 3]
let b = @[11, 12, 13, 10]
let c = @[10, 10, 10]

forEach [x, y, z], [a, b, c]:
  echo (x + y) * z

forEachIndexed j, [x, y, z], [a, b, c]:
  echo "index: " & $j & ", " & $((x + y) * z)
```

```
120
140
160
index: 0, 120
index: 1, 140
index: 2, 160
```

```Nim
import loopfusion

let a = @[false, true, false, true, false]
let b = @[1, 2, 3, 4, 5]
let c = @["a: ", "b: ", "c: ", "d: ", "e: "]
var d: seq[int] = @[]

forEachIndexed j, [x, y, z], [a, b, c]:
  if x:
    d.add $(y*y)
  else:
    d.add $y

echo d
```
```
@[0, 140, 320]
```
