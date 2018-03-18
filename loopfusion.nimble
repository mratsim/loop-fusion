packageName   = "loopfusion"
version       = "0.0.1"
author        = "Mamy André-Ratsimbazafy (Numforge SARL)"
description   = "Loop efficiently over a variadic number of containers"
license       = "MIT or Apache License 2.0"

### Dependencies
requires "nim >= 0.18.0"

### Helper functions
proc test(name: string, defaultLang = "c") =
  if not dirExists "build":
    mkDir "build"
  if not dirExists "nimcache":
    mkDir "nimcache"
  --run
  --nimcache: "nimcache"
  switch("out", ("./build/" & name))
  setCommand lang, "tests/" & name & ".nim"

### tasks
task test, "Run all tests":
  test "all_tests"
