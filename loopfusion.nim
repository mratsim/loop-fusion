import macros

proc getSubType*(T: NimNode): NimNode =
  # Get the subtype T of an input
  result = getTypeInst(T)[1]

proc injectParam(param: NimNode): NimNode =
  nnkPragmaExpr.newTree(
      newIdentNode($param),
      nnkPragma.newTree(ident("inject"))
    )

macro generateZip(zipName: NimNode, index: untyped, enumerate: static[bool], args: varargs[typed]): untyped =
  let N = args.len
  assert N > 1, "Error: only 0 or 1 argument passed." &
    "\nThe zip macros should be called directly " &
    "with all input sequences like so: zip(s1, s2, s3)."

  # 1. Initialization
  result = newStmtList()

  # Now we create a `zipImpl` iterator with N arguments

  # 2. Create the parameters: Return type + N arguments
  var zipParams = newSeq[NimNode](N+1)

  # 2.1 Return type
  zipParams[0] = newPar()
  if enumerate:
    zipParams[0].add getType(int)
  for i in 0 ..< N:
    zipParams[0].add getSubType(args[i])

  # 2.2 Parameters
  for i in 0 ..< N:
    let s = newIdentDefs(ident("seq" & $i), args[i].getTypeInst)
    zipParams[i+1] = s

  # 3. Body
  var zipBody = newStmtList()

  # 3.1 Check that the length of the seqs are the same
  let arg0 = args[0]
  let size0 = newIdentNode("size0")
  zipBody.add quote do:
    let `size0` = `arg0`.len

  for i, t in args:
    let size_t = newIdentNode("checksize_" & $i)
    let check = quote do:
      let `size_t` = `t`.len
      assert(`size0` == `size_t`, "ForEach macro: parameter " & `t`.astTostr &
                                  " in position #" & $(`i`) &
                                  " has a different length.")
    zipBody.add check

  # 3.2 We setup the loop index
  let iter = if enumerate:
                newIdentNode($index)
              else:
                newIdentNode("i")
  let iter_inject = if enumerate: injectParam(iter)
                    else: iter

  # 3.2 We create the innermost (s0[i], s1[i], s2[i], ..., s100[i])
  var inner = newPar()
  if enumerate:
    inner.add newIdentNode($index)
  for arg in args:
    inner.add nnkBracketExpr.newTree(arg, iter)

  # 3.3 We create the for loop
  var forLoop = nnkForStmt.newTree()
  # for i in 0 ..< size0:
  #   yield (s0[i], s1[i], s2[i], ..., s100[i])
  #   OR
  #   yield (i, s0[i], s1[i], s2[i], ..., s100[i])

  forLoop.add iter_inject

  forLoop.add nnkInfix.newTree(
      ident("..<"),
      newIntLitNode(0),
      size0
    )

  forLoop.add nnkYieldStmt.newTree(
      inner
    )

  zipBody.add forLoop

  # 3.4 Construct the iterator
  var zipImpl = newProc(
    name = zipName,
    params = zipParams,
    body = zipBody,
    procType = nnkIteratorDef
  )

  # 4. Make it visible
  result.add zipImpl

macro forEachImpl[N: static[int]](
  index: untyped,
  enumerate: static[bool],
  values: untyped,
  containers: array[N, typed],
  loopBody: untyped
  ): untyped =
  # 1. Initialization
  result = newStmtList()

  # 2. Create the idents injected
  var idents_inject = newPar()
  for ident in values:
    idents_inject.add injectParam(ident)

  # 3. Create the index injected if applicable
  let idx_inject = injectParam(index)

  # 2. Generate the matching zip iterator
  let zipName = if enumerate:
                  genSym(nskIterator,"enumerateZipImpl_" & $N & "_")
                else:
                  genSym(nskIterator,"zipImpl_" & $N & "_")
  result.add getAST(generateZip(zipName, index, enumerate, containers))

  # 3. Creating the call
  var zipCall = newCall(zipName)
  containers.copyChildrenTo zipCall

  # 4. For statement
  var forLoop = nnkForStmt.newTree()
  if enumerate:
    forLoop.add idx_inject
  idents_inject.copyChildrenTo forLoop
  forLoop.add zipCall
  forLoop.add loopBody

  # 5. Finalize
  result.add forLoop

template forEach*[N: static[int]](
  values: untyped,
  containers: array[N, typed],
  loopBody: untyped
  ): untyped =
  ## Iterates over a variadic number of sequences

  ## Example:
  ##
  ## let a = @[1, 2, 3]
  ## let b = @[11, 12, 13]
  ## let c = @[10, 10, 10]
  ##
  ## forEach [x, y, z], [a, b, c]:
  ##   echo (x + y) * z
  forEachImpl(discarded, false, values, containers, loopBody)

template forEachIndexed*[N: static[int]](
  index: untyped,
  values: untyped,
  containers: array[N, typed],
  loopBody: untyped
  ): untyped =
  ## Iterates over a variadic number of sequences

  ## Example:
  ##
  ## let a = @[1, 2, 3]
  ## let b = @[11, 12, 13]
  ## let c = @[10, 10, 10]
  ##
  ## forEachIndexed i, [x, y, z], [a, b, c]:
  ##   echo i, (x + y) * z

  forEachImpl(index, true, values, containers, loopBody)

proc replaceNodes(ast: NimNode, values: NimNode, containers: NimNode): NimNode =
  # Args:
  #   - The full syntax tree
  #   - an array of replacement value
  #   - an array of identifiers to replace
  proc inspect(node: NimNode): NimNode =
    case node.kind:
    of {nnkIdent, nnkSym}:
      for i, c in containers:
        if node.eqIdent($c):
          return values[i]
      return node
    of nnkEmpty:
      return node
    else:
      var rTree = node.kind.newTree()
      for child in node:
        rTree.add inspect(child)
      return rTree

  result = inspect(ast)

macro loopFusion*(
  containers: varargs[seq],
  loopBody: untyped
  ): untyped =
  ## Loop without temporaries over any number of seq
  ##
  ## Example:
  ##
  ## let a = @[1, 2, 3]
  ## let b = @[11, 12, 13]
  ## let c = @[10, 10, 10]
  ##
  ## let d = @[5, 6, 7]
  ##
  ## loopFusion(d,a,b,c):
  ##   let z = b + c
  ##   echo d + a * z

  let N = containers.len

  # 2. Prepare the replacement values
  var values = nnkBracket.newTree
  for i in 0 ..< N:
    values.add ident($containers[i] & "_loopFusion_")

  # 3. Replace the AST
  let replacedAST = replaceNodes(loopBody, values, containers)

  # 4. ForEach wants array
  var arrayContainer = nnkBracket.newTree
  for i in 0 ..< N:
    arrayContainer.add containers[i]

  # 5. Finalize
  result = quote do:
    forEach(`values`, `arrayContainer`, `replacedAST`)


when isMainModule:
  block:
    let a = @[1, 2, 3]
    let b = @[11, 12, 13]
    let c = @[10, 10, 10]

    forEach [x, y, z], [a, b, c]:
      echo (x + y) * z

    forEachIndexed j, [x, y, z], [a, b, c]:
      echo "index: " & $j & ", " & $((x + y) * z)

  block:
    let a = @[1, 2, 3]
    let b = @[11, 12, 13]
    let c = @[10, 10, 10]
    var d: seq[int] = @[]

    forEachIndexed j, [x, y, z], [a, b, c]:
      d.add (x + y) * z * j

    echo d

  block:
    let a = @[1, 2, 3]
    let b = @[11, 12, 13]
    let c = @[10, 10, 10]

    let d = @[5, 6, 7]

    loopFusion(d,a,b,c):
      let z = b + c
      echo d + a * z
