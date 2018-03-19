# Loop Fusion

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

Iterate efficiently over a variadic number of containers.

  * The loop structure is generated inline at compile-time.
  * There are no temporary allocation.

## Status

The containers can be seq of any type. In the future this will be generalized to `openarray` or even an `Iterable` concept.

The API is not settled yet.

### Known limitations

At the moment:

  - all the seqs must contain the same element type.
  - the iteration values cannot be assigned to.


## Usage

```Nim
import loopfusion

let a = @[1, 2, 3]
let b = @[11, 12, 13]
let c = @[10, 10, 10]

forEach x in a, y in b, z in c:
  echo (x + y) * z

# 120
# 140
# 160

# i is the iteration index [0, 1, 2]
forEach i, x in a, y in b, z in c:
  d.add (x + y) * z * i

# index: 0, 120
# index: 1, 140
# index: 2, 160
```

```Nim
import loopfusion

let a = @[1, 2, 3]
let b = @[11, 12, 13]
let c = @[10, 10, 10]

let d = @[5, 6, 7]

loopFusion(d,a,b,c):
  let z = b + c
  echo d + a * z

# 26
# 50
# 76
```

## Future API and naming

Suggestions welcome.

I have noted the following:

### Names

Loopfusion might be a bit confusing since there is no loop to fuse at start.
In spirit however, it is similar while "real" loop fusion merge multiple loops over multiple sequences.

Alternative names proposed: lift, loopover

At one point it would be convenient to have an `elementwise` block that does:

```Nim
elementwise:
  a += b * c
```

Naming up to discussion as well.

### Pending upstream

For expression would be a great boon and would allow something similar to:

```Nim
let As = @[1, 2, 3]
let Bs = @[10, 10, 10]

let c = forEach a in As, b in Bs:
          (a * b) + b

echo c # @[11, 22, 33]
```
