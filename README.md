# Loop Fusion

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

Iterate efficiently over a variadic number of containers.

  * The loop structure is generated inline at compile-time.
  * There are no temporary allocation.

### Status

The containers can be seq of any type. In the future this will be generalized to `openarray` or even an `Iterable` concept.

Currently `forEach` and `forEachIndexed`

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

let a = @[1, 2, 3]
let b = @[11, 12, 13]
let c = @[10, 10, 10]
var d: seq[int] = @[]

forEachIndexed j, [x, y, z], [a, b, c]:
  d.add (x + y) * z * j

echo d
```
```
@[0, 140, 320]
```
