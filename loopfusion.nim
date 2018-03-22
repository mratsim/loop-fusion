import macros

proc getSubType(T: NimNode): NimNode =
  # Get the subtype T of an input
  result = getTypeInst(T)[1]

proc injectParam(param: NimNode): NimNode =
  nnkPragmaExpr.newTree(
      newIdentNode($param),
      nnkPragma.newTree(ident("inject"))
    )

proc pop(tree: var NimNode): NimNode =
  result = tree[tree.len-1]
  tree.del(tree.len-1)

macro generateZip(
                  zipName: NimNode,
                  index: untyped,
                  enumerate: static[bool],
                  containers: varargs[typed],
                  mutables: static[seq[int]] # Those are a seq[bool]: https://github.com/nim-lang/Nim/issues/7375
                  ): untyped =
  let N = containers.len
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
    let subt = getSubType(containers[i])
    if mutables[i] == 1:
      zipParams[0].add nnkVarTy.newtree(subt)
    else:
      zipParams[0].add subt

  # 2.2 Parameters
  for i in 0 ..< N:
    let s = newIdentDefs(ident("seq" & $i), containers[i].getTypeInst)
    zipParams[i+1] = s

  # 3. Body
  var zipBody = newStmtList()

  # 3.1 Check that the length of the seqs are the same
  let container0 = containers[0]
  let size0 = newIdentNode("size0")
  zipBody.add quote do:
    let `size0` = `container0`.len

  for i, t in containers:
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
  for arg in containers:
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
  mutables: static[array[N, int]], # Those are a seq[bool]: https://github.com/nim-lang/Nim/issues/7375
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
  result.add getAST(generateZip(zipName, index, enumerate, containers, mutables))

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

macro forEach*(args: varargs[untyped]): untyped =
  ## Iterates over a variadic number of sequences

  ## Example:
  ##
  ## let a = @[1, 2, 3]
  ## let b = @[11, 12, 13]
  ## let c = @[10, 10, 10]
  ##
  ## forEach [x, y, z], [a, b, c]:
  ##   echo (x + y) * z

  # In an untyped context, we can't deal with types at all so we reformat the args
  # and then pass the new argument to a typed macro

  var params = args
  var loopBody = params.pop

  var index = getType(int) # to be replaced with the index variable if applicable
  var values = nnkBracket.newTree()
  var containers = nnkBracket.newTree()
  var mutables: seq[bool] = @[]
  var N = 0
  var enumerate = false

  for arg in params:
    case arg.kind:
    of nnkIdent:
      if N == 0:
        index = arg
        enumerate = true
      else:
        error "Syntax error: argument " & ($arg.kind).substr(3) & " in position #" & $N & " was unexpected."
    of nnkInfix:
      if eqIdent(arg[0], "in"):
        values.add arg[1]
        if arg[2].kind == nnkVarTy:
          containers.add arg[2][0]
          mutables.add true
        else:
          containers.add arg[2] # TODO: use an intermediate assignation if it's a result of a proc to avoid calling it multiple time
          mutables.add false
      else:
        error "Syntax error: argument " & ($arg.kind).substr(3) & " in position #" & $N & " was unexpected."
    else:
      error "Syntax error: argument " & ($arg.kind).substr(3) & " in position #" & $N & " was unexpected."
    inc N

  if enumerate:
    result = quote do:
      forEachImpl(`index`, true, `values`, `containers`, `mutables`,`loopBody`)
  else:
    result = quote do:
      forEachImpl(`index`, false, `values`, `containers`, `mutables`,`loopBody`)


when isMainModule:
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
