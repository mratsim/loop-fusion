import loopfusion

proc main() =
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
  

when isMainModule:
  main()
